# Structural tests for the workflow templates (tile/templates/workflows/) and
# this repository's own test workflow. Templates refer to the installed tile as
# $SITE_TILE (.tessl/plugins/mhclg-aaai/proj-site) and to the trunk as __TRUNK__.

W="$TILE/templates/workflows"

test_check_workflow_runs_check_on_pull_requests() {
  f=$(cat "$W/site-check.yml")
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
  f=$(cat "$W/site-pages.yml")
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
  for f in "$W"/*.yml; do
    for rel in $(grep -o '\$SITE_TILE/[A-Za-z0-9_./-]*' "$f" | sed 's|\$SITE_TILE/||' | sort -u); do
      assert_file "$TILE_ROOT/$rel"
    done
    assert_contains "$(cat "$f")" "SITE_TILE: .tessl/plugins/mhclg-aaai/proj-site"
  done
}

test_templates_have_no_tabs_and_pin_action_versions() {
  for f in "$W"/*.yml "$REPO_ROOT/.github/workflows/test.yml"; do
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
