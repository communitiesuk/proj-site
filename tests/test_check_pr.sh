# Tests for tile/scripts/check-pr.sh.
CHECK="$TILE/scripts/check-pr.sh"

# fixture [trunk-summary]: repo in $TMP/r on branch feat-x (off dev) that
# adds a change entry. If a summary name is given it is committed on dev.
fixture() {
  local r="$TMP/r"
  make_repo "$r"
  mkdir -p "$r/site/content/changes" "$r/site/content/summaries"
  : > "$r/README"
  [ -z "${1:-}" ] || echo s > "$r/site/content/summaries/$1.md"
  commit_at "$r" 2026-01-01T00:00:00Z -m base
  git -C "$r" checkout -q -b feat-x
  echo c > "$r/site/content/changes/2026-01-02-feat-x.md"
  commit_at "$r" 2026-01-02T00:00:00Z -m entry
}

# run_check <now> [args...]: run from the repo; sets $out (stderr+stdout), $rc.
run_check() {
  local now=$1; shift
  rc=0
  out=$(cd "$TMP/r" && "$CHECK" --base dev --now "$now" "$@" 2>&1) || rc=$?
}

# stub_gh <json>: SITE_GH stub printing the json.
stub_gh() {
  printf '#!/bin/sh\ncat <<'"'"'J'"'"'\n%s\nJ\n' "$1" > "$TMP/gh"
  chmod +x "$TMP/gh"
  export SITE_GH="$TMP/gh"
}

test_no_change_entry_fails() {
  fixture 2026-W01
  git -C "$TMP/r" rm -q site/content/changes/2026-01-02-feat-x.md
  commit_at "$TMP/r" 2026-01-03T00:00:00Z -m rm
  run_check 2026-01-07T12:00:00Z
  assert_eq 1 "$rc"
  assert_contains "$out" "site/content/changes/2026-01-07-feat-x.md"
  assert_contains "$out" "site-writing"
}

test_thursday_without_summary_fails() {
  fixture
  run_check 2026-01-08T09:00:00Z
  assert_eq 1 "$rc"
  assert_contains "$out" "site/content/summaries/2026-W02.md"
  assert_contains "$out" "site-writing"
}

test_thursday_with_summary_on_trunk_passes() {
  fixture 2026-W02
  run_check 2026-01-08T09:00:00Z
  assert_eq 0 "$rc" "$out"
}

test_thursday_with_summary_in_other_open_pr_passes() {
  fixture
  stub_gh '[{"number":7,"files":[{"path":"site/content/summaries/2026-W02.md"}]}]'
  run_check 2026-01-08T09:00:00Z --pr 3 --repo o/n
  assert_eq 0 "$rc" "$out"
}

test_current_pr_own_listing_is_excluded() {
  fixture
  stub_gh '[{"number":3,"files":[{"path":"site/content/summaries/2026-W02.md"}]}]'
  run_check 2026-01-08T09:00:00Z --pr 3 --repo o/n
  assert_eq 1 "$rc"
}

test_gh_failure_warns_and_fails() {
  fixture
  printf '#!/bin/sh\nexit 1\n' > "$TMP/gh"; chmod +x "$TMP/gh"
  export SITE_GH="$TMP/gh"
  run_check 2026-01-08T09:00:00Z --pr 3 --repo o/n
  assert_eq 1 "$rc"
  assert_contains "$out" "warning"
  assert_contains "$out" "2026-W02.md"
}

test_wednesday_uses_previous_thursday_week() {
  fixture 2026-W01
  run_check 2026-01-07T12:00:00Z
  assert_eq 0 "$rc" "$out"
  rm -rf "$TMP/r"
  fixture
  run_check 2026-01-07T12:00:00Z
  assert_eq 1 "$rc"
  assert_contains "$out" "site/content/summaries/2026-W01.md"
}

test_monday_fails_until_pr_adds_summary() {
  fixture
  run_check 2026-01-12T09:00:00Z
  assert_eq 1 "$rc"
  assert_contains "$out" "2026-W02.md"
  echo s > "$TMP/r/site/content/summaries/2026-W02.md"
  commit_at "$TMP/r" 2026-01-12T00:00:00Z -m summary
  run_check 2026-01-12T09:00:00Z
  assert_eq 0 "$rc" "$out"
}

test_both_failures_reported_together() {
  fixture
  git -C "$TMP/r" rm -q site/content/changes/2026-01-02-feat-x.md
  commit_at "$TMP/r" 2026-01-03T00:00:00Z -m rm
  run_check 2026-01-08T09:00:00Z
  assert_eq 1 "$rc"
  assert_contains "$out" "site/content/changes/2026-01-08-feat-x.md"
  assert_contains "$out" "site/content/summaries/2026-W02.md"
}

test_due_week_sunday_and_monday() {
  assert_eq 2026-W01 "$("$CHECK" --due-week --now 2026-01-04T10:00:00Z)"
  assert_eq 2026-W01 "$("$CHECK" --due-week --now 2026-01-05T00:00:00Z)"
}

test_due_week_53() {
  assert_eq 2026-W53 "$("$CHECK" --due-week --now 2027-01-04T00:00:00Z)"
}

test_usage_error() {
  rc=0; "$CHECK" --bogus >/dev/null 2>&1 || rc=$?
  assert_eq 2 "$rc"
  rc=0; "$CHECK" --now 2026-01-01T00:00:00Z >/dev/null 2>&1 || rc=$?
  assert_eq 2 "$rc"
}

test_slug_uses_github_head_ref_on_a_detached_checkout() {
  fixture 2026-W01
  git -C "$TMP/r" rm -q site/content/changes/2026-01-02-feat-x.md
  commit_at "$TMP/r" 2026-01-03T00:00:00Z -m rm
  git -C "$TMP/r" checkout -q --detach
  rc=0
  out=$(cd "$TMP/r" && GITHUB_HEAD_REF="Feature/Date_Filter" bash "$CHECK" --base dev --now 2026-01-07T12:00:00Z 2>&1) || rc=$?
  assert_eq 1 "$rc"
  assert_contains "$out" "site/content/changes/2026-01-07-feature-date-filter.md"
}
