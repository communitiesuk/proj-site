# Tests for the workflow templates (tile/templates/workflows/) and this
# repository's own test workflow. Templates refer to the trunk as __TRUNK__ and
# ship as *.yml.txt: the registry install dropped *.yml files. Each template's
# "Locate the proj-site tile" step reads proj-site from the project's
# tessl.json, uses a file: source as it stands or installs only proj-site at
# the listed version into a folder under $RUNNER_TEMP, fails clearly when it
# cannot, and passes $SITE_TILE to later steps through $GITHUB_ENV. The step's
# script is extracted and run here against a stub npx.

W="$TILE/templates/workflows"

test_check_workflow_runs_check_on_pull_requests() {
  f=$(cat "$W/site-check.yml.txt")
  assert_contains "$f" "pull_request:"
  assert_contains "$f" "fetch-depth: 0"
  assert_contains "$f" "contents: read"
  assert_contains "$f" "pull-requests: read"
  assert_contains "$f" 'bash "$SITE_TILE/skills/site-setup/scripts/check-pr.sh"'
  assert_contains "$f" '--pr "${{ github.event.pull_request.number }}"'
  assert_contains "$f" 'GH_TOKEN: ${{ github.token }}'
  assert_not_contains "$f" "pages: write" "check workflow needs no write scopes"
}

test_pages_workflow_builds_and_deploys_on_trunk() {
  f=$(cat "$W/site-pages.yml.txt")
  assert_contains "$f" "branches: [__TRUNK__]"
  assert_contains "$f" "fetch-depth: 0"
  for p in "contents: read" "pull-requests: read" "issues: read" "pages: write" "id-token: write"; do
    assert_contains "$f" "$p"
  done
  assert_contains "$f" 'bash "$SITE_TILE/skills/site-setup/core/build.sh"'
  assert_contains "$f" "actions/configure-pages"
  assert_contains "$f" "actions/upload-pages-artifact"
  assert_contains "$f" "actions/deploy-pages"
  assert_contains "$f" "HUGO_VERSION:"
}

test_templates_reference_scripts_that_exist_in_the_tile() {
  for f in "$W"/*.yml.txt; do
    for rel in $(grep -o '\$SITE_TILE/[A-Za-z0-9_./-]*' "$f" | sed 's|\$SITE_TILE/||' | sort -u); do
      assert_file "$TILE_ROOT/$rel"
    done
  done
}

test_templates_have_no_tabs_and_pin_action_versions() {
  for f in "$W"/*.yml.txt "$REPO_ROOT/.github/workflows/test.yml"; do
    ! grep -q "$(printf '\t')" "$f" || fail "tab in $f"
    ! grep -E 'uses: [^@]+$' "$f" || fail "unpinned action in $f"
  done
}

test_repo_test_workflow_runs_the_suite() {
  f=$(cat "$REPO_ROOT/.github/workflows/test.yml")
  assert_contains "$f" "pull_request:"
  assert_contains "$f" "branches: [dev]"
  assert_contains "$f" "tests/run.sh"
  assert_contains "$f" "HUGO_VERSION:"
  assert_contains "$f" "actions/setup-python"
}

LOCATE="Locate the proj-site tile"

# locate_script <template>: the "Locate the proj-site tile" step's run script,
# dedented.
locate_script() {
  awk -v name="- name: $LOCATE" '
    index($0, name) { found = 1; next }
    found && !inrun && /^ *run: \|$/ { inrun = 1; match($0, /^ */); ind = RLENGTH + 2; next }
    inrun { if ($0 != "" && match($0, /^ */) && RLENGTH < ind) exit; print substr($0, ind + 1) }
  ' "$1"
}

test_templates_locate_the_tile_before_use() {
  for f in "$W"/*.yml.txt; do
    n=$(basename "$f")
    ! grep -qE '^ +SITE_TILE:' "$f" || fail "$n sets SITE_TILE in an env block"
    loc=$(grep -nF -- "- name: $LOCATE" "$f" | head -n1 | cut -d: -f1)
    use=$(grep -nF -- 'bash "$SITE_TILE/' "$f" | head -n1 | cut -d: -f1)
    [ -n "$loc" ] || fail "$n has no \"$LOCATE\" step"
    [ "$loc" -lt "$use" ] || fail "$n: the tile is used (line $use) before it is located (line $loc)"
    [ -n "$(locate_script "$f")" ] || fail "$n: the locate step has no run script"
    assert_not_contains "$(cat "$f")" "TESSL_SHARE_USAGE_DATA"
  done
  assert_eq "$(locate_script "$W/site-check.yml.txt")" "$(locate_script "$W/site-pages.yml.txt")" \
    "the locate step is the same in both templates"
}

# setup_locate <tessl.json content or "">: a workspace in $TMP/ws, a stub npx
# first on PATH that logs "<dir>|<args>" to $TMP/npx.log and, by $STUB_MODE
# (ok, empty, fail), creates the tile in its working directory, creates
# nothing, or exits 1.
setup_locate() {
  mkdir -p "$TMP/ws" "$TMP/rt" "$TMP/bin"; : > "$TMP/genv"; : > "$TMP/npx.log"
  [ -z "$1" ] || printf '%s\n' "$1" > "$TMP/ws/tessl.json"
  cat > "$TMP/bin/npx" <<STUB
#!/usr/bin/env bash
echo "\$PWD|\$*" >> "$TMP/npx.log"
case "\${STUB_MODE:-ok}" in
  ok) mkdir -p .tessl/plugins/mhclg-aaai/proj-site/skills/site-setup/scripts
      touch .tessl/plugins/mhclg-aaai/proj-site/skills/site-setup/scripts/check-pr.sh ;;
  fail) exit 1 ;;
esac
STUB
  chmod +x "$TMP/bin/npx"
  locate_script "$W/site-check.yml.txt" > "$TMP/locate.sh"
}

# run_locate: run the step's script in the workspace as Actions would; sets rc.
run_locate() {
  rc=0
  (cd "$TMP/ws" && PATH="$TMP/bin:$PATH" RUNNER_TEMP="$TMP/rt" GITHUB_ENV="$TMP/genv" \
    bash -e "$TMP/locate.sh") > "$TMP/out" 2>&1 || rc=$?
}

test_locate_installs_only_proj_site_at_the_pinned_version() {
  json='{"name":"p","mode":"managed","dependencies":{"mhclg-aaai/myelin":{"version":"0.5.2"},"mhclg-aaai/proj-site":{"version":"0.3.0"}}}'
  setup_locate "$json"; cp "$TMP/ws/tessl.json" "$TMP/before.json"
  run_locate
  assert_eq 0 "$rc" "exit status; output: $(cat "$TMP/out")"
  assert_eq 1 "$(wc -l < "$TMP/npx.log" | tr -d ' ')" "npx ran once"
  dir=$(cut -d'|' -f1 "$TMP/npx.log"); args=$(cut -d'|' -f2- "$TMP/npx.log")
  case $dir in "$TMP/rt"/*) ;; *) fail "npx ran in $dir, not under RUNNER_TEMP" ;; esac
  assert_eq "-y @tessl/cli@0.123.0 install --yes --accept-warnings" "$args"
  assert_eq '{"mhclg-aaai/proj-site":"0.3.0"}' "$(jq -c '.dependencies | map_values(.version)' "$dir/tessl.json")"
  cmp -s "$TMP/before.json" "$TMP/ws/tessl.json" || fail "the workspace tessl.json changed"
  assert_no_path "$TMP/ws/.tessl"
  assert_eq "SITE_TILE=$dir/.tessl/plugins/mhclg-aaai/proj-site" "$(cat "$TMP/genv")"
}

test_locate_uses_a_file_source_as_it_stands() {
  setup_locate '{"name":"p","mode":"vendored","dependencies":{"mhclg-aaai/proj-site":{"source":"file:tile"}}}'
  mkdir -p "$TMP/ws/tile/skills/site-setup/scripts"; touch "$TMP/ws/tile/skills/site-setup/scripts/check-pr.sh"
  run_locate
  assert_eq 0 "$rc" "exit status; output: $(cat "$TMP/out")"
  assert_eq "" "$(cat "$TMP/npx.log")" "npx not run"
  assert_eq "" "$(ls -A "$TMP/rt")" "nothing under RUNNER_TEMP"
  assert_eq "SITE_TILE=tile" "$(cat "$TMP/genv")"
}

test_locate_fails_when_proj_site_is_not_listed() {
  for json in '{"name":"p","dependencies":{"mhclg-aaai/myelin":{"version":"0.5.2"}}}' ''; do
    rm -rf "$TMP/ws"; setup_locate "$json"
    run_locate
    [ "$rc" -ne 0 ] || fail "expected failure for tessl.json [$json]"
    assert_contains "$(cat "$TMP/out")" "mhclg-aaai/proj-site"
    assert_contains "$(cat "$TMP/out")" "tessl.json"
    assert_eq "" "$(cat "$TMP/npx.log")" "npx not run"
    assert_eq "" "$(cat "$TMP/genv")" "SITE_TILE not set"
  done
}

test_locate_fails_when_proj_site_is_not_pinned() {
  setup_locate '{"name":"p","dependencies":{"mhclg-aaai/proj-site":{}}}'
  run_locate
  [ "$rc" -ne 0 ] || fail "expected failure"
  assert_contains "$(cat "$TMP/out")" "mhclg-aaai/proj-site"
  assert_contains "$(cat "$TMP/out")" "version"
  assert_eq "" "$(cat "$TMP/npx.log")" "npx not run"
}

test_locate_fails_when_the_tile_does_not_arrive() {
  for mode in empty fail; do
    rm -rf "$TMP/ws" "$TMP/rt"
    setup_locate '{"name":"p","dependencies":{"mhclg-aaai/proj-site":{"version":"9.9.9"}}}'
    STUB_MODE=$mode run_locate
    [ "$rc" -ne 0 ] || fail "expected failure when npx [$mode]"
    assert_contains "$(cat "$TMP/out")" "not installed" "message for npx [$mode]"
    assert_contains "$(cat "$TMP/out")" "9.9.9" "message names the version for npx [$mode]"
    assert_eq "" "$(cat "$TMP/genv")" "SITE_TILE not set for npx [$mode]"
  done
}
