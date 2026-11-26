# Tests for tile/skills/site-setup/scripts/require-site-check.sh, against the
# stub gh (tests/stub-gh.sh) and its fixture sets under tests/stub-gh/.

REQ="$TILE/scripts/require-site-check.sh"
P='{"required_status_checks":{"strict":false,"checks":[{"context":"check"}]},"enforce_admins":null,"required_pull_request_reviews":null,"restrictions":null}'
C='{"contexts":["check"]}'
PROT=repos/example/widget/branches/dev/protection
BY_HAND='Set it by hand: https://github.com/example/widget/settings/branches'

# use_set <name>: a fixture repo on dev with origin example/widget, the stub
# first on PATH as gh, answering from a copy of tests/stub-gh/<name>.
use_set() {
  make_repo "$TMP/w"; git -C "$TMP/w" remote add origin https://github.com/example/widget.git
  commit_at "$TMP/w" 2026-01-01T00:00:00Z -m init
  mkdir -p "$TMP/bin" "$TMP/stub"; cp "$REPO_ROOT/tests/stub-gh.sh" "$TMP/bin/gh"; chmod +x "$TMP/bin/gh"
  cp -R "$REPO_ROOT/tests/stub-gh/$1/." "$TMP/stub/"; : > "$TMP/stub/calls"
}

# req [args...]: run the script in the fixture repo; sets rc, out (stdout), err.
req() {
  rc=0
  (cd "$TMP/w" && PATH="$TMP/bin:$PATH" STUB_GH_DIR="$TMP/stub" bash "$REQ" "$@") >"$TMP/o" 2>"$TMP/e" || rc=$?
  out=$(cat "$TMP/o"); err=$(cat "$TMP/e")
}

calls() { cat "$TMP/stub/calls"; }

test_unprotected_trunk_gets_protection_requiring_check() {
  use_set unprotected; req
  assert_eq 0 "$rc" "exit; stderr: $err"
  assert_eq "$(printf 'GET %s \nPUT %s %s' "$PROT" "$PROT" "$P")" "$(calls)"
  assert_eq "Required the site check on dev." "$out"
}

test_existing_required_checks_gain_check() {
  use_set with-checks; req
  assert_eq 0 "$rc" "exit; stderr: $err"
  assert_eq "$(printf 'GET %s \nPOST %s/required_status_checks/contexts %s' "$PROT" "$PROT" "$C")" "$(calls)"
  assert_eq "Added the site check to the required checks on dev." "$out"
}

test_already_required_changes_nothing() {
  for set in already already-checks-form; do
    use_set "$set"; req
    assert_eq 0 "$rc" "exit for $set"
    assert_eq "GET $PROT " "$(calls)" "only the read for $set"
    assert_eq "The site check is already required on dev; nothing changed." "$out" "$set"
    rm -rf "$TMP/w" "$TMP/stub"
  done
}

test_protection_without_status_checks_is_left_to_the_user() {
  use_set no-checks; req
  assert_eq 3 "$rc" "exit"
  assert_eq "GET $PROT " "$(calls)" "no write call"
  assert_eq "$BY_HAND" "$out"
  assert_not_contains "$out" "gh api"
}

test_failed_put_prints_the_put() {
  use_set put-fails; req
  assert_eq 1 "$rc" "exit"
  assert_eq "echo '$P' | gh api -X PUT $PROT --input -" "$out"
  assert_contains "$err" "HTTP 403"
}

test_failed_post_prints_the_post_never_a_put() {
  use_set post-fails; req
  assert_eq 1 "$rc" "exit"
  assert_eq "echo '$C' | gh api -X POST $PROT/required_status_checks/contexts --input -" "$out"
  assert_not_contains "$out" "PUT"
  assert_contains "$err" "HTTP 403"
}

test_failed_first_read_prints_only_the_settings_line() {
  use_set no-access; req
  assert_eq 1 "$rc" "exit"
  assert_eq "GET $PROT " "$(calls)" "no write call"
  assert_eq "$BY_HAND" "$out"
  assert_not_contains "$out" "gh api"
  assert_contains "$err" "HTTP 404"
}

test_flags_override_the_defaults() {
  use_set unprotected
  req --trunk main --repo other/thing
  assert_eq 0 "$rc" "exit; stderr: $err"
  assert_contains "$(calls)" "PUT repos/other/thing/branches/main/protection"
  assert_eq "Required the site check on main." "$out"
}

test_resolves_trunk_and_repo_as_site_init_does() {
  use_set unprotected
  git -C "$TMP/w" branch -m dev feature-x; git -C "$TMP/w" branch main
  req
  assert_contains "$(calls)" "GET repos/example/widget/branches/main/protection"
}

test_usage_and_unresolvable_defaults_exit_2() {
  use_set unprotected
  req --bogus; assert_eq 2 "$rc" "unknown flag"
  req --trunk; assert_eq 2 "$rc" "--trunk without a value"
  git -C "$TMP/w" remote remove origin
  req --trunk dev; assert_eq 2 "$rc" "no --repo and no origin"
  mkdir -p "$TMP/plain"
  rc=0; (cd "$TMP/plain" && PATH="$TMP/bin:$PATH" STUB_GH_DIR="$TMP/stub" bash "$REQ" --repo example/widget) >/dev/null 2>&1 || rc=$?
  assert_eq 2 "$rc" "--repo without --trunk outside a repository"
  : > "$TMP/stub/calls"
  rc=0; (cd "$TMP/plain" && PATH="$TMP/bin:$PATH" STUB_GH_DIR="$TMP/stub" bash "$REQ" --repo example/widget --trunk dev) >/dev/null 2>&1 || rc=$?
  assert_eq 0 "$rc" "--repo with --trunk outside a repository"
}

test_strict_is_never_sent_true() {
  for set in unprotected with-checks; do
    use_set "$set"; req
    assert_not_contains "$(calls)" '"strict":true' "$set"
    rm -rf "$TMP/w" "$TMP/stub"
  done
}
