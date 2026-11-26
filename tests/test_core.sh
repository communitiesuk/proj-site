# Tests for tile/core: lib.sh helpers, timeline.sh and build.sh.

# --- lib.sh ----------------------------------------------------------------

test_yaml_get_reads_scalars_lists_and_nested_keys() {
  . "$TILE/core/lib.sh"
  printf 'name: "Quoted name"  # c\ncontent_type: code\nlanguages: [python, go]\nupcoming:\n  source: github-issues\n' > y.yaml
  assert_eq "Quoted name" "$(yaml_get y.yaml name)"
  assert_eq "code" "$(yaml_get y.yaml content_type)"
  assert_eq "python go" "$(yaml_get y.yaml languages)"
  assert_eq "github-issues" "$(yaml_get y.yaml upcoming.source)"
  assert_eq "" "$(yaml_get y.yaml missing)"
  assert_eq "" "$(yaml_get y.yaml source)" "nested key is not top level"
}

test_iso_week_handles_year_boundaries() {
  . "$TILE/core/lib.sh"
  assert_eq 2026-W01 "$(iso_week 2026-01-01)"
  assert_eq 2026-W01 "$(iso_week 2026-01-04)"
  assert_eq 2026-W02 "$(iso_week 2026-01-05)"
  assert_eq 2026-W53 "$(iso_week 2027-01-01)"
  assert_eq 2027-W01 "$(iso_week 2027-01-04)"
}

test_frontmatter_get_reads_only_front_matter() {
  . "$TILE/core/lib.sh"
  printf -- '---\ntitle: "A title"\nperiod_end: 2026-01-06\n---\ntitle: not this\n' > f.md
  assert_eq "A title" "$(frontmatter_get f.md title)"
  assert_eq "2026-01-06" "$(frontmatter_get f.md period_end)"
  assert_eq "" "$(frontmatter_get f.md missing)"
}

# --- timeline.sh -----------------------------------------------------------

test_timeline_lists_the_trailer_chain_in_order() {
  make_chain_repo "$TMP/r"
  out=$(bash "$TILE/core/timeline.sh" "$TMP/r")
  got=$(printf '%s' "$out" | jq -r '.[] | [.date, .stage, .kind, .path, .title] | join("|")')
  expected="2026-01-01|explored|discovery-added|docs/discovery/0001-idea.md|An idea
2026-01-02|decided|adr-added|docs/adr/0001-choice.md|Which choice?
2026-01-03|decided|note-consumed|docs/adr/0001-choice.md|Which choice?
2026-01-04|decided|plan-added|plans/0001-build.md|Build it
2026-01-06|built|plan-completed|plans/0001-build.md|Build it
2026-01-06|shipped|release|v0.1.0|v0.1.0
2026-01-08|decided|adr-revised|docs/adr/0001-choice.md|Which choice?"
  assert_eq "$expected" "$got"
  assert_eq "true" "$(printf '%s' "$out" | jq '[.[].recent] | all')" "all recent without since"
  printf '%s' "$out" | jq -e '.[0].commit | test("^[0-9a-f]{7,}$")' >/dev/null || fail "commit sha"
}

test_timeline_marks_recent_since_date() {
  make_chain_repo "$TMP/r"
  got=$(bash "$TILE/core/timeline.sh" "$TMP/r" 2026-01-06 | jq -r '[.[] | select(.recent) | .kind] | join(",")')
  assert_eq "plan-completed,release,adr-revised" "$got"
}

test_timeline_empty_history_and_non_repo() {
  make_repo "$TMP/e"; echo x > "$TMP/e/x"; commit_at "$TMP/e" 2026-01-01T00:00:00Z -m init
  assert_eq "[]" "$(bash "$TILE/core/timeline.sh" "$TMP/e" | jq -c .)"
  mkdir "$TMP/plain"
  set +e; bash "$TILE/core/timeline.sh" "$TMP/plain" >/dev/null 2>&1; rc=$?; set -e
  assert_eq 2 "$rc"
}

# --- build.sh --------------------------------------------------------------

test_build_sections_follow_content_type() {
  for ct in knowledge code both; do
    rm -rf "$TMP/p" "$TMP/out"
    make_project "$TMP/p" "$ct"
    build "$TMP/p" "$TMP/out" --no-render
    s="$TMP/out/src/content"
    for always in updates weeknotes coming-next; do assert_file "$s/$always/_index.md"; done
    for old in changes summaries upcoming reference; do assert_no_path "$s/$old"; done
    assert_file "$s/_index.md"
    case $ct in
      knowledge) assert_file "$s/guides/start.md"; assert_file "$s/docs/guide.md"
                 assert_no_path "$s/docs/reference" ;;
      code) assert_no_path "$s/guides"; assert_no_path "$s/docs/guide.md"
            assert_file "$s/docs/reference/pkg/mod.md" ;;
      both) assert_file "$s/guides/start.md"; assert_file "$s/docs/guide.md"
            assert_file "$s/docs/reference/pkg/mod.md" ;;
    esac
  done
  # knowledge with no hand-written doc page: no Docs section, no Docs tab.
  rm -rf "$TMP/p" "$TMP/out"
  make_project "$TMP/p" knowledge
  git -C "$TMP/p" rm -q site/content/docs/guide.md
  commit_at "$TMP/p" 2026-01-10T10:00:00Z -m "Drop the doc"
  build "$TMP/p" "$TMP/out" --no-render
  assert_no_path "$TMP/out/src/content/docs"
  assert_not_contains "$(cat "$TMP/out/src/hugo.toml")" 'name = "Docs"'
  assert_file "$TMP/out/src/content/guides/start.md"
}

test_build_generates_config_entries_and_data() {
  make_project "$TMP/p" both
  SITE_BASE_URL="https://example.github.io/fixture/" build "$TMP/p" "$TMP/out" --no-render
  s="$TMP/out/src"
  cfg=$(cat "$s/hugo.toml")
  assert_contains "$cfg" 'title = "Fixture project"'
  assert_contains "$cfg" 'baseURL = "https://example.github.io/fixture/"'
  # Tabs, in order, with their names and addresses.
  menu=$(awk -F'"' '/^  name = /{n=$2} /^  pageRef = /{print n "|" $2}' "$s/hugo.toml" | paste -sd ';' -)
  assert_eq "Overview|/;Guides|/guides/;Docs|/docs/;Weeknotes|/weeknotes/;Latest updates|/updates/;Coming next|/coming-next/" "$menu"
  for sec in guides:Guides docs:Docs weeknotes:Weeknotes updates:"Latest updates" coming-next:"Coming next"; do
    assert_contains "$(cat "$s/content/${sec%%:*}/_index.md")" "title: ${sec#*:}"
  done
  assert_contains "$(cat "$s/content/_index.md")" "OVERVIEW-TEXT"
  entry=$(cat "$s/content/updates/2026-01-05-entry-one.md")
  assert_contains "$entry" 'week: "2026-W02"'
  assert_not_contains "$entry" "pr:"
  assert_contains "$(cat "$s/content/docs/reference/pkg/mod.md")" "REFERENCE-TEXT"
  assert_eq "UPCOMING-ITEM" "$(jq -r '.[0].title' "$s/data/upcoming.json")"
  # Recent since the latest summary's period_end (2026-01-06).
  assert_eq "plan-completed,release,adr-revised" \
    "$(jq -r '[.[] | select(.recent) | .kind] | join(",")' "$s/data/timeline.json")"
  # The project's own files are not modified.
  assert_eq "" "$(git -C "$TMP/p" status --porcelain)"
}

test_build_adds_pr_number_when_online() {
  make_project "$TMP/p" knowledge
  printf '#!/bin/sh\n# stub gh: api repos/<r>/commits/<sha>/pulls --jq ...\necho 42\n' > "$TMP/gh"; chmod +x "$TMP/gh"
  SITE_OFFLINE=0 SITE_GH="$TMP/gh" build "$TMP/p" "$TMP/out" --no-render
  assert_contains "$(cat "$TMP/out/src/content/updates/2026-01-05-entry-one.md")" "pr: 42"
}

test_build_rejects_bad_project() {
  make_project "$TMP/p" both
  sed -i.bak 's/content_type: both/content_type: nonsense/' "$TMP/p/site/project.yaml"
  set +e; build "$TMP/p" "$TMP/out" --no-render 2>err; rc=$?; set -e
  assert_eq 2 "$rc"; assert_contains "$(cat err)" "content_type"
  rm "$TMP/p/site/project.yaml"
  set +e; build "$TMP/p" "$TMP/out2" --no-render 2>err; rc=$?; set -e
  assert_eq 2 "$rc"; assert_contains "$(cat err)" "project.yaml"
  set +e; build 2>/dev/null; rc=$?; set -e
  assert_eq 2 "$rc"
}

test_build_names_failing_adapter() {
  make_project "$TMP/p" knowledge
  printf 'echo boom >&2; exit 3\n' > "$TMP/adapters/upcoming/fake.sh"
  set +e; build "$TMP/p" "$TMP/out" --no-render 2>err; rc=$?; set -e
  [ "$rc" -ne 0 ] || fail "expected failure"
  assert_contains "$(cat err)" "upcoming adapter"
}

test_build_renders_site_with_hugo() {
  command -v "${HUGO:-hugo}" >/dev/null || { echo "hugo not installed"; return 1; }
  make_project "$TMP/p" both
  build "$TMP/p" "$TMP/out"
  p="$TMP/out/public"
  assert_contains "$(cat "$p/index.html")" "OVERVIEW-TEXT"
  updates=$(cat "$p/updates/index.html")
  assert_contains "$updates" "ENTRY-ONE"
  assert_contains "$updates" "2026-W02"
  assert_contains "$updates" "Build it"
  assert_contains "$(cat "$p/coming-next/index.html")" "UPCOMING-ITEM"
  assert_contains "$(cat "$p/weeknotes/index.html")" "Week of 2026-01-01"
  assert_contains "$(cat "$p/guides/start/index.html")" "HOWTO-TEXT"
  assert_contains "$(cat "$p/docs/guide/index.html")" "GUIDE-TEXT"
  assert_contains "$(cat "$p/docs/reference/pkg/mod/index.html")" "REFERENCE-TEXT"
  for now in guides docs weeknotes updates coming-next; do assert_file "$p/$now/index.html"; done
  for old in summaries changes upcoming reference; do assert_no_path "$p/$old"; done
}

test_rendered_links_respect_a_base_path() {
  command -v "${HUGO:-hugo}" >/dev/null || { echo "hugo not installed"; return 1; }
  make_project "$TMP/p" knowledge
  SITE_BASE_URL="https://example.github.io/sub/" build "$TMP/p" "$TMP/out"
  home=$(cat "$TMP/out/public/index.html")
  assert_contains "$home" 'class="site" href="/sub/"'
  ! grep -q 'href="/"' "$TMP/out/public/index.html" || fail "a link ignores the base path"
}
