# Self-test of the harness helpers.
test_assert_eq_passes_and_fails() {
  assert_eq a a
  ! assert_eq a b 2>/dev/null
}
test_make_repo_has_identity() {
  make_repo "$TMP/r"
  assert_eq "Test Author" "$(git -C "$TMP/r" config user.name)"
}
