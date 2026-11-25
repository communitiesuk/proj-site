# Structural tests for the workflow templates (tile/templates/workflows/) and
# this repository's own test workflow. Templates refer to the installed tile as
# $SITE_TILE (.tessl/plugins/mhclg-aaai/proj-site), set for the whole job, and
# to the trunk as __TRUNK__. They ship as *.yml.txt: the registry install
# dropped *.yml files. Each template installs the tile itself, with a pinned
# tessl CLI and the project's committed tessl.json, whatever its tessl mode,
# then fails the job unless the tile arrived (a skipped install exits 0).

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
    assert_contains "$(cat "$f")" "SITE_TILE: .tessl/plugins/mhclg-aaai/proj-site"
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

TESSL_INSTALL='npx -y @tessl/cli@0.123.0 install --yes --accept-warnings'
TILE_CHECK='[ -f "$SITE_TILE/skills/site-setup/scripts/check-pr.sh" ]'

# line_of <file> <fixed string>: number of the first line containing it, or 0.
line_of() { grep -nF -- "$2" "$1" | head -n1 | cut -d: -f1 | grep . || echo 0; }

test_templates_set_site_tile_for_the_whole_job() {
  for f in "$W"/*.yml.txt; do
    grep -qE '^      SITE_TILE: \.tessl/plugins/mhclg-aaai/proj-site$' "$f" ||
      fail "SITE_TILE is not in the job env of $(basename "$f")"
    assert_eq 1 "$(grep -c 'SITE_TILE:' "$f")" "SITE_TILE set once in $(basename "$f")"
  done
}

test_templates_install_the_tile_and_check_it_before_use() {
  for f in "$W"/*.yml.txt; do
    n=$(basename "$f")
    install=$(line_of "$f" "$TESSL_INSTALL")
    check=$(line_of "$f" "$TILE_CHECK")
    use=$(line_of "$f" 'bash "$SITE_TILE/')
    [ "$install" -gt 0 ] || fail "$n does not run: $TESSL_INSTALL"
    [ "$check" -gt 0 ] || fail "$n does not check the tile arrived"
    [ "$install" -lt "$check" ] && [ "$check" -lt "$use" ] ||
      fail "$n: install ($install), check ($check) and use ($use) are out of order"
    assert_contains "$(sed -n "${check},\$p" "$f" | head -n4)" "tessl.json" \
      "$n: the check's failure message names tessl.json"
    assert_not_contains "$(cat "$f")" "TESSL_SHARE_USAGE_DATA"
  done
}

