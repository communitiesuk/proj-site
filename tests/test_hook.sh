# Tests for tile/scripts/hook-pr-create.sh.
HOOK="$TILE/scripts/hook-pr-create.sh"

# fixture: repo $TMP/r with site/project.yaml and an entry already on dev,
# on branch feat-x with one unrelated commit.
fixture() {
  local r="$TMP/r"
  make_repo "$r"
  mkdir -p "$r/site/content/changes"
  echo "name: x" > "$r/site/project.yaml"
  echo old > "$r/site/content/changes/2025-12-01-old.md"
  commit_at "$r" 2026-01-01T00:00:00Z -m base
  git -C "$r" checkout -q -b feat-x
  echo w > "$r/work.txt"
  commit_at "$r" 2026-01-02T00:00:00Z -m work
}

add_entry() {
  echo n > "$TMP/r/site/content/changes/2026-01-02-feat-x.md"
  commit_at "$TMP/r" 2026-01-03T00:00:00Z -m entry
}

# run_hook <json>: sets $rc, $out (stdout), $err (stderr).
run_hook() {
  rc=0
  err=$(printf '%s' "$1" | "$HOOK" 2>&1 >"$TMP/out") || rc=$?
  out=$(cat "$TMP/out")
}

bash_json() { # command
  jq -nc --arg c "$1" --arg d "$TMP/r" \
    '{tool_name:"Bash",tool_input:{command:$c},cwd:$d}'
}

test_blocks_without_entry() {
  fixture
  run_hook "$(bash_json 'gh pr create --title x')"
  assert_eq 2 "$rc" "exit"
  assert_contains "$err" "site-writing"
  assert_contains "$err" "site/content/changes/"
  assert_contains "$err" "feat-x"
  assert_eq "" "$out" "stdout"
}

test_blocks_when_chained_command() {
  fixture
  run_hook "$(bash_json 'git push && gh pr create --fill')"
  assert_eq 2 "$rc"
}

test_passes_with_entry() {
  fixture; add_entry
  run_hook "$(bash_json 'gh pr create --title x')"
  assert_eq 0 "$rc"
  assert_eq "" "$err"
  assert_eq "" "$out"
}

test_existing_entry_on_trunk_still_blocks() {
  fixture
  echo more >> "$TMP/r/site/content/changes/2025-12-01-old.md"
  commit_at "$TMP/r" 2026-01-03T00:00:00Z -m modify
  run_hook "$(bash_json 'gh pr create')"
  assert_eq 2 "$rc"
}

test_site_trunk_env() {
  fixture
  git -C "$TMP/r" branch main dev
  git -C "$TMP/r" checkout -q main
  add_entry
  git -C "$TMP/r" checkout -q feat-x
  # against dev: no entry on feat-x; against main: entry is on main, not feat-x
  git -C "$TMP/r" branch -f other feat-x
  git -C "$TMP/r" checkout -q -b feat-y main
  echo z > "$TMP/r/z.txt"; commit_at "$TMP/r" 2026-01-04T00:00:00Z -m z
  # trunk=dev: feat-y adds the entry -> pass
  rc=0; printf '%s' "$(bash_json 'gh pr create')" | SITE_TRUNK=dev "$HOOK" 2>/dev/null || rc=$?
  assert_eq 0 "$rc" "trunk dev"
  # trunk=main: feat-y adds nothing -> block
  rc=0; printf '%s' "$(bash_json 'gh pr create')" | SITE_TRUNK=main "$HOOK" 2>/dev/null || rc=$?
  assert_eq 2 "$rc" "trunk main"
}

test_falls_back_to_main() {
  fixture
  git -C "$TMP/r" branch -m dev main
  run_hook "$(bash_json 'gh pr create')"
  assert_eq 2 "$rc"
}

test_passes_other_bash_command() {
  fixture
  run_hook "$(bash_json 'git status')"
  assert_eq 0 "$rc"
  assert_eq "" "$err"
}

test_passes_non_bash_tool() {
  fixture
  run_hook "$(jq -nc --arg d "$TMP/r" \
    '{tool_name:"Write",tool_input:{command:"gh pr create"},cwd:$d}')"
  assert_eq 0 "$rc"
  assert_eq "" "$err"
}

test_passes_on_malformed_json() {
  fixture
  run_hook '{not json'
  assert_eq 0 "$rc"
  assert_eq "" "$err"
  run_hook ''
  assert_eq 0 "$rc"
}

test_passes_without_project_yaml() {
  fixture
  git -C "$TMP/r" rm -q site/project.yaml
  commit_at "$TMP/r" 2026-01-03T00:00:00Z -m rm
  run_hook "$(bash_json 'gh pr create')"
  assert_eq 0 "$rc"
  assert_eq "" "$err"
}

test_passes_outside_git_repo() {
  mkdir "$TMP/plain"
  run_hook "$(jq -nc --arg d "$TMP/plain" \
    '{tool_name:"Bash",tool_input:{command:"gh pr create"},cwd:$d}')"
  assert_eq 0 "$rc"
  assert_eq "" "$err"
}

test_template_registers_hook() {
  f="$TILE/templates/claude-hook.json"
  assert_file "$f"
  assert_eq Bash "$(jq -r '.hooks.PreToolUse[0].matcher' "$f")"
  assert_eq command "$(jq -r '.hooks.PreToolUse[0].hooks[0].type' "$f")"
  assert_contains "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$f")" \
    '"$CLAUDE_PROJECT_DIR"/.site/hook-pr-create.sh'
}
