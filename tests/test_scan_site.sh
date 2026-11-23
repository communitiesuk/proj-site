# Tests for tests/scan-site.sh, the verification-only scan of a built site.

scan() { bash "$REPO_ROOT/tests/scan-site.sh" "$@"; }

make_built() { # project-dir public-dir
  make_repo "$1"; echo x > "$1/x"; commit_at "$1" 2026-01-01T00:00:00Z -m init
  mkdir -p "$2/a"; echo '<p>A clean page about search.</p>' > "$2/a/index.html"
}

test_scan_passes_a_clean_site() {
  make_built "$TMP/p" "$TMP/pub"
  scan "$TMP/p" "$TMP/pub" >/dev/null
}

test_scan_finds_author_names() {
  make_built "$TMP/p" "$TMP/pub"
  echo '<p>Thanks to Test Author.</p>' > "$TMP/pub/a/thanks.html"
  set +e; out=$(scan "$TMP/p" "$TMP/pub" 2>&1); rc=$?; set -e
  assert_eq 1 "$rc"; assert_contains "$out" "Test Author"; assert_contains "$out" "thanks.html"
}

test_scan_finds_secret_patterns() {
  make_built "$TMP/p" "$TMP/pub"
  echo 'token ghp_abcdefghijklmnopqrstuvwxyz0123456789' > "$TMP/pub/a/s.html"
  set +e; out=$(scan "$TMP/p" "$TMP/pub" 2>&1); rc=$?; set -e
  assert_eq 1 "$rc"; assert_contains "$out" "s.html"
  assert_not_contains "$out" "ghp_abcdefghijklmnopqrstuvwxyz0123456789" "the secret is not echoed"
}
