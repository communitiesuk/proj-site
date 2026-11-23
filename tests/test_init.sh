# Tests for tile/scripts/site-init.sh, run on fixture projects.

init() { bash "$TILE/scripts/site-init.sh" "$@"; }

make_target() { # dir
  make_repo "$1"
  git -C "$1" remote add origin https://github.com/example/widget.git
  printf '{"name":"widget","mode":"vendored","dependencies":{}}\n' > "$1/tessl.json"
  echo "# Widget" > "$1/README.md"
  commit_at "$1" 2026-01-01T00:00:00Z -m init
}

snapshot() { (cd "$1" && find . -path ./.git -prune -o -type f -print | sort | xargs shasum); }

test_init_creates_project_and_workflows() {
  make_target "$TMP/w"; cd "$TMP/w"
  out=$(init --trunk dev)
  assert_eq "widget" "$(. "$TILE/core/lib.sh"; yaml_get site/project.yaml name)"
  assert_eq "example/widget" "$(. "$TILE/core/lib.sh"; yaml_get site/project.yaml repository)"
  assert_eq "knowledge" "$(. "$TILE/core/lib.sh"; yaml_get site/project.yaml content_type)"
  assert_eq "github-issues" "$(. "$TILE/core/lib.sh"; yaml_get site/project.yaml upcoming.source)"
  assert_file site/content/overview.md
  assert_eq "$(cat "$TILE/templates/workflows/site-check.yml")" "$(cat .github/workflows/site-check.yml)"
  pages=$(cat .github/workflows/site-pages.yml)
  assert_contains "$pages" "branches: [dev]"
  assert_not_contains "$pages" "__TRUNK__"
  assert_no_path .claude/settings.json
  assert_contains "$out" "Pages"
}

test_init_detects_python_and_trunk() {
  make_target "$TMP/w"; cd "$TMP/w"
  mkdir src && echo 'x = 1' > src/a.py && commit_at . 2026-01-02T00:00:00Z -m py
  git branch -m dev main
  init >/dev/null
  assert_eq "both" "$(. "$TILE/core/lib.sh"; yaml_get site/project.yaml content_type)"
  assert_eq "python" "$(. "$TILE/core/lib.sh"; yaml_get site/project.yaml languages)"
  assert_contains "$(cat .github/workflows/site-pages.yml)" "branches: [main]"
}

test_init_content_type_flag_and_validation() {
  make_target "$TMP/w"; cd "$TMP/w"
  init --content-type code --trunk dev >/dev/null
  assert_eq "code" "$(. "$TILE/core/lib.sh"; yaml_get site/project.yaml content_type)"
  make_target "$TMP/v"; cd "$TMP/v"
  set +e; init --content-type nonsense 2>/dev/null; rc=$?; set -e
  assert_eq 2 "$rc"; assert_no_path site/project.yaml
}

test_second_run_changes_nothing_and_keeps_edits() {
  make_target "$TMP/w"; cd "$TMP/w"
  init --trunk dev --with-claude-hook >/dev/null
  echo "# hand edit" >> site/project.yaml
  before=$(snapshot .)
  init --trunk dev --with-claude-hook >/dev/null
  assert_eq "$before" "$(snapshot .)"
  assert_contains "$(cat site/project.yaml)" "# hand edit"
}

test_hook_flag_merges_settings_once() {
  make_target "$TMP/w"; cd "$TMP/w"
  mkdir .claude && printf '{"permissions":{"allow":["Bash(ls)"]}}\n' > .claude/settings.json
  init --trunk dev --with-claude-hook >/dev/null
  s=.claude/settings.json
  assert_eq '["Bash(ls)"]' "$(jq -c .permissions.allow "$s")" "existing settings kept"
  assert_eq 1 "$(jq '[.hooks.PreToolUse[].hooks[] | select(.command | contains("hook-pr-create.sh"))] | length' "$s")"
  init --trunk dev --with-claude-hook >/dev/null
  assert_eq 1 "$(jq '[.hooks.PreToolUse[].hooks[] | select(.command | contains("hook-pr-create.sh"))] | length' "$s")"
}

test_init_warns_without_vendored_mode_and_requires_repo_root() {
  make_target "$TMP/w"; cd "$TMP/w"
  printf '{"name":"widget","dependencies":{}}\n' > tessl.json
  err=$(init --trunk dev 2>&1 >/dev/null)
  assert_contains "$err" "vendored"
  mkdir -p "$TMP/w/sub"; cd "$TMP/w/sub"
  set +e; init 2>/dev/null; rc=$?; set -e
  assert_eq 2 "$rc"
  cd "$TMP"; mkdir plain; cd plain
  set +e; init 2>/dev/null; rc=$?; set -e
  assert_eq 2 "$rc"
}

test_init_falls_back_to_the_current_branch_in_a_new_repo() {
  mkdir "$TMP/n"; cd "$TMP/n"; git init -q -b trunkish
  init >/dev/null
  assert_contains "$(cat .github/workflows/site-pages.yml)" "branches: [trunkish]"
}
