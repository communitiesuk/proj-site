# Tests for the upcoming-work adapters (tile/adapters/upcoming).

GH_ISSUES="$TILE/adapters/upcoming/github-issues.sh"

# Make a project in $TMP/p; write a gh stub that prints $1 (recorded JSON).
setup_gh() {
  mkdir -p "$TMP/p/site"
  printf 'name: X\nrepository: org/repo\n' > "$TMP/p/site/project.yaml"
  printf '%s\n' "$1" > "$TMP/recorded.json"
  cat > "$TMP/gh" <<STUB
#!/usr/bin/env bash
echo "\$*" > "$TMP/gh.args"
cat "$TMP/recorded.json"
STUB
  chmod +x "$TMP/gh"
  export SITE_GH="$TMP/gh"
}

run_issues() { bash "$GH_ISSUES" "$TMP/p"; }

test_theme_label_extracted() {
  setup_gh '[{"number":7,"title":"Add X","state":"OPEN","url":"u","labels":[{"name":"theme:Release assurance"}]}]'
  assert_eq '[{"title":"Add X","ref":"#7","state":"open","theme":"Release assurance"}]' "$(run_issues | jq -c .)"
}

test_no_theme_label_gives_empty() {
  setup_gh '[{"number":1,"title":"T","state":"OPEN","url":"u","labels":[{"name":"bug"}]}]'
  assert_eq '' "$(run_issues | jq -r '.[0].theme')"
}

test_first_theme_among_many_labels() {
  setup_gh '[{"number":2,"title":"T","state":"OPEN","url":"u","labels":[{"name":"bug"},{"name":"theme: Alpha "},{"name":"theme:Beta"}]}]'
  assert_eq 'Alpha' "$(run_issues | jq -r '.[0].theme')"
}

test_state_lowercased() {
  setup_gh '[{"number":3,"title":"T","state":"OPEN","url":"u","labels":[]}]'
  assert_eq 'open' "$(run_issues | jq -r '.[0].state')"
}

test_empty_list() {
  setup_gh '[]'
  assert_eq '[]' "$(run_issues | jq -c .)"
}

test_repository_read_from_project_yaml() {
  setup_gh '[]'
  run_issues >/dev/null
  assert_contains "$(cat "$TMP/gh.args")" '--repo org/repo'
  assert_contains "$(cat "$TMP/gh.args")" '--state open'
}

test_repository_fallback_to_gh_repo_view() {
  setup_gh '[]'
  printf 'name: X\n' > "$TMP/p/site/project.yaml"
  cat > "$TMP/gh" <<STUB
#!/usr/bin/env bash
case "\$*" in
  "repo view"*) echo '{"nameWithOwner":"fall/back"}';;
  *) echo "\$*" > "$TMP/gh.args"; echo '[]';;
esac
STUB
  run_issues >/dev/null
  assert_contains "$(cat "$TMP/gh.args")" '--repo fall/back'
}

test_gh_failure_exits_nonzero_with_message() {
  setup_gh '[]'
  printf '#!/usr/bin/env bash\necho boom >&2\nexit 1\n' > "$TMP/gh"
  local rc=0
  run_issues >"$TMP/out" 2>"$TMP/err" || rc=$?
  [ "$rc" -ne 0 ] || fail "expected non-zero exit"
  assert_eq '' "$(cat "$TMP/out")" "stdout"
  [ -s "$TMP/err" ] || fail "expected stderr message"
}

test_stub_default_item() {
  mkdir -p "$TMP/p/site"
  assert_eq '[{"title":"Stub item","ref":"#0","state":"open","theme":""}]' \
    "$(bash "$TILE/adapters/upcoming/stub.sh" "$TMP/p" | jq -c .)"
}

test_stub_reads_file() {
  mkdir -p "$TMP/p/site"
  echo '[{"title":"A","ref":"#1","state":"open","theme":"T"}]' > "$TMP/p/site/upcoming-stub.json"
  assert_eq '[{"title":"A","ref":"#1","state":"open","theme":"T"}]' \
    "$(bash "$TILE/adapters/upcoming/stub.sh" "$TMP/p" | jq -c .)"
}
