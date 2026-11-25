# Self-test of the harness helpers.
test_assert_eq_passes_and_fails() {
  assert_eq a a
  ! assert_eq a b 2>/dev/null
}
test_make_repo_has_identity() {
  make_repo "$TMP/r"
  assert_eq "Test Author" "$(git -C "$TMP/r" config user.name)"
}
test_failed_assertion_fails_the_test() {
  # Run the harness on a file whose only test fails mid-way; it must report FAIL.
  d=$(mktemp -d); cp "$REPO_ROOT/tests/run.sh" "$REPO_ROOT/tests/lib.sh" "$d/"
  printf 'test_x() {\n  assert_eq a b\n  true\n}\n' > "$d/test_x.sh"
  set +e; out=$(bash "$d/run.sh" 2>&1); rc=$?; set -e
  rm -rf "$d"
  assert_eq 1 "$rc"; assert_contains "$out" "FAIL test_x.sh test_x"
}

test_tests_run_without_github_variables() {
  # In Actions, GITHUB_HEAD_REF names the PR's branch; a test must not see it.
  d=$(mktemp -d); cp "$REPO_ROOT/tests/run.sh" "$REPO_ROOT/tests/lib.sh" "$d/"
  printf 'test_x() {\n  assert_eq "" "$(env | grep "^GITHUB_" || true)"\n}\n' > "$d/test_x.sh"
  set +e; out=$(GITHUB_HEAD_REF=feature-y GITHUB_ACTIONS=true bash "$d/run.sh" 2>&1); rc=$?; set -e
  rm -rf "$d"
  assert_eq 0 "$rc" "a test saw GITHUB_* variables: $out"
}
