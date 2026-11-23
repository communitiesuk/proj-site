# Tests that the tile survives the tessl registry, which delivers only files
# with listed extensions and drops the executable bit.

test_tile_files_have_registry_safe_extensions() {
  bad=$(cd "$TILE_ROOT" && find . -type f | grep -vE '\.(md|txt|json|yml|yaml|toml|sh|py|js|ts|tsx|jsx)$' || true)
  assert_eq "" "$bad" "files the registry would drop"
}

test_plugin_manifest_names_the_tile_and_its_skills() {
  m="$TILE_ROOT/.tessl-plugin/plugin.json"
  assert_eq "mhclg-aaai/proj-site" "$(jq -r .name "$m")"
  assert_eq "./skills/" "$(jq -r .skills "$m")"
  jq -re '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "$m" >/dev/null || fail "version"
  for d in "$TILE_ROOT"/skills/*/; do assert_file "$d/SKILL.md"; done
}

test_build_runs_without_executable_bits() {
  # Copy the tile as the registry delivers it: no executable bits anywhere.
  cp -R "$TILE_ROOT" "$TMP/tile"; chmod -R a-x+X "$TMP/tile"
  make_repo "$TMP/p"; mkdir -p "$TMP/p/site/content"
  printf 'name: P\ncontent_type: knowledge\nupcoming:\n  source: stub\n' > "$TMP/p/site/project.yaml"
  printf -- '---\ntitle: Overview\n---\nHELLO\n' > "$TMP/p/site/content/overview.md"
  commit_at "$TMP/p" 2026-01-01T00:00:00Z -m init
  SITE_OFFLINE=1 bash "$TMP/tile/skills/site-setup/core/build.sh" "$TMP/p" "$TMP/out" --no-render
  assert_eq "Stub item" "$(jq -r '.[0].title' "$TMP/out/src/data/upcoming.json")"
  assert_file "$TMP/out/src/layouts/_default/baseof.html"
  assert_no_path "$TMP/out/src/layouts/_default/baseof.html.txt"
}

test_everything_shipped_is_inside_a_skill() {
  # The registry archive holds only what the manifest declares: skills/.
  stray=$(cd "$TILE_ROOT" && find . -type f ! -path './skills/*' ! -path './.tessl-plugin/*' ! -path './evals/*' | sort)
  assert_eq "" "$stray" "files outside skills/ would not be published"
}

test_no_yaml_files_in_the_tile() {
  # Observed: a registry install of 0.1.0 dropped both *.yml workflow templates.
  found=$(cd "$TILE_ROOT" && find . -type f \( -name '*.yml' -o -name '*.yaml' \) ! -path './evals/*')
  assert_eq "" "$found"
}
