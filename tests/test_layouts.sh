# Tests for the rendered layouts (tile/skills/site-setup/core/layouts): the
# base layout's tabs, colours and theme switch, and each page's structure.

# render <content_type>: build and render the fixture into $TMP/out/public.
render() {
  command -v "${HUGO:-hugo}" >/dev/null || { echo "hugo not installed"; return 1; }
  make_project "$TMP/p" "$1"
  build "$TMP/p" "$TMP/out"
  PUB="$TMP/out/public"
}

# css_block <html-file> <selector>: the declarations of the first rule whose
# selector is exactly <selector>.
css_block() {
  awk -v sel="$2 {" 'index($0, sel) { on = 1; sub(".*" "\\{", "") } on { print } on && /}/ { exit }' "$1"
}

test_tabs_in_order_with_current_tab_marked() {
  render both
  tabs=$(sed -n 's/.*<nav[^>]*>\(.*\)<\/nav>.*/\1/p' "$PUB/guides/index.html" | grep -o '<a [^>]*>[^<]*</a>')
  assert_eq "Overview|Guides|Docs|Weeknotes|Latest updates|Coming next" \
    "$(printf '%s\n' "$tabs" | sed 's/<[^>]*>//g' | paste -sd '|' -)"
  assert_eq 1 "$(printf '%s\n' "$tabs" | grep -c 'aria-current="page"')"
  assert_contains "$(printf '%s\n' "$tabs" | grep 'aria-current="page"')" ">Guides</a>"
}

test_colour_tokens_light_and_dark() {
  render knowledge
  f="$PUB/index.html"
  light=$(css_block "$f" ':root')
  dark=$(css_block "$f" ':root[data-theme="dark"]')
  nojs=$(css_block "$f" ':root:not([data-theme="light"])')
  for v in '#f3f3f3' '#fff' '#d4d4d4' '#1b1b1b' '#5f6368' '#00625E' '#932A71' '#E5E5E5' '#fff7d6' \
           '#1D70B8' '#6F3E9B' '#A85A00' '#00703C'; do
    assert_contains "$light" "$v" "light $v"
  done
  for v in '#14181a' '#1e2426' '#3a4346' '#d6dada' '#a2a9ab' '#5fc7c0' '#d97fb8' '#00625E' '#2a3033' '#3a3320' \
           '#6cb4ff' '#b794e0' '#f0a64d' '#4fc08a'; do
    assert_contains "$dark" "$v" "dark $v"
    assert_contains "$nojs" "$v" "no-script dark $v"
  done
  assert_contains "$(cat "$f")" "prefers-color-scheme: dark"
}

test_section_intros() {
  render both
  assert_contains "$(cat "$PUB/guides/index.html")" "How to use the project, step by step."
  assert_contains "$(cat "$PUB/docs/index.html")" "Technical documentation, including reference generated from the code."
  assert_contains "$(cat "$PUB/weeknotes/index.html")" "A short weekly account of what the project explored, decided, built and shipped."
  assert_contains "$(cat "$PUB/updates/index.html")" "What changed, pull request by pull request, by week and on a timeline."
  assert_contains "$(cat "$PUB/coming-next/index.html")" "Work the project plans to do next."
}

test_project_index_keeps_its_own_intro() {
  command -v "${HUGO:-hugo}" >/dev/null || { echo "hugo not installed"; return 1; }
  make_project "$TMP/p" knowledge
  printf -- '---\ntitle: Guides\nintro: OWN-INTRO\n---\n' > "$TMP/p/site/content/guides/_index.md"
  build "$TMP/p" "$TMP/out"
  assert_contains "$(cat "$TMP/out/public/guides/index.html")" "OWN-INTRO"
  assert_not_contains "$(cat "$TMP/out/public/guides/index.html")" "How to use the project, step by step."
}

test_theme_switch() {
  render knowledge
  html=$(cat "$PUB/index.html")
  assert_contains "$html" '<button'
  button=$(printf '%s' "$html" | tr '\n' ' ' | grep -o '<button[^>]*>.*</button>')
  assert_contains "$(printf '%s' "$button" | sed 's/<[^>]*aria-hidden="true"[^>]*>[^<]*<\/[a-z]*>//g; s/<[^>]*>//g')" "Dark mode"
  assert_contains "$button" 'aria-hidden="true"'
  head=$(printf '%s' "$html" | tr '\n' ' ' | sed 's/<\/head>.*//')
  for word in prefers-color-scheme localStorage data-theme; do
    assert_contains "$head" "$word" "head script $word"
  done
}

test_no_external_requests() {
  render both
  for f in $(find "$PUB" -name '*.html'); do
    ! grep -Eq '(src|srcset)="(https?:)?//' "$f" || fail "external src in $f"
    ! grep -Eq '<link[^>]+href="(https?:)?//' "$f" || fail "external stylesheet in $f"
    ! grep -q '@import' "$f" || fail "@import in $f"
  done
}

# pos <haystack> <needle>: byte offset of the first <needle>, or fail.
pos() { local i; i=$(printf '%s' "$1" | grep -bo -- "$2" | head -1 | cut -d: -f1); [ -n "$i" ] || fail "[$2] not found"; echo "$i"; }

test_overview_page() {
  render both
  home=$(cat "$PUB/index.html")
  for intro in "How to use the project, step by step." \
               "Technical documentation, including reference generated from the code." \
               "A short weekly account of what the project explored, decided, built and shipped." \
               "What changed, pull request by pull request, by week and on a timeline." \
               "Work the project plans to do next."; do
    assert_contains "$home" "$intro"
  done
  assert_eq 5 "$(printf '%s' "$home" | grep -o 'class="card' | wc -l | tr -d ' ')" "a card per section"
  assert_contains "$home" "What happened this week"
  assert_contains "$home" "Week of 2026-01-01"
  assert_contains "$home" "SUMMARY-TEXT See #42."
  assert_contains "$home" "Weeknotes are a short weekly account of what the project explored, decided, built and shipped."
  assert_not_contains "$home" "Latest summary"
}

test_overview_without_a_weeknote() {
  command -v "${HUGO:-hugo}" >/dev/null || { echo "hugo not installed"; return 1; }
  make_project "$TMP/p" knowledge
  git -C "$TMP/p" rm -q site/content/summaries/2026-W01.md
  commit_at "$TMP/p" 2026-01-10T10:00:00Z -m "No weeknote"
  build "$TMP/p" "$TMP/out"
  assert_not_contains "$(cat "$TMP/out/public/index.html")" "What happened this week"
}

test_updates_page_tabs() {
  render knowledge
  u=$(cat "$PUB/updates/index.html")
  assert_contains "$u" 'role="tablist"'
  assert_eq 2 "$(printf '%s' "$u" | grep -o 'role="tab"' | wc -l | tr -d ' ')" "two tab controls"
  assert_eq 2 "$(printf '%s' "$u" | grep -o 'role="tabpanel"' | wc -l | tr -d ' ')" "two panels"
  assert_contains "$u" ">By week</"
  assert_contains "$u" ">Timeline</"
  assert_contains "$u" "since the last weeknote"
  assert_not_contains "$u" "since the last summary"
}

test_coming_next_page() {
  render knowledge
  c=$(cat "$PUB/coming-next/index.html" | tr '\n' ' ')
  gh=https://github.com/example/fixture
  # Grouped by theme (Alpha, Beta, No theme), oldest first within a group.
  a=$(pos "$c" '<h3[^>]*>Alpha</h3>'); d=$(pos "$c" ITEM-D); ia=$(pos "$c" ITEM-A)
  b=$(pos "$c" '<h3[^>]*>Beta</h3>'); ib=$(pos "$c" ITEM-B)
  n=$(pos "$c" '<h3[^>]*>No theme</h3>'); ic=$(pos "$c" ITEM-C)
  [ "$a" -lt "$d" ] && [ "$d" -lt "$ia" ] && [ "$ia" -lt "$b" ] && [ "$b" -lt "$ib" ] \
    && [ "$ib" -lt "$n" ] && [ "$n" -lt "$ic" ] || fail "order: Alpha D A, Beta B, No theme C"
  for i in 11 12 13 14; do assert_contains "$c" "href=\"$gh/issues/$i\""; done
  # Only A expands, with its summary and a link to the discussion.
  assert_eq 1 "$(printf '%s' "$c" | grep -o '<details' | wc -l | tr -d ' ')" "one <details>"
  details=$(printf '%s' "$c" | grep -o '<details.*</details>')
  assert_contains "$details" "ITEM-A"; assert_contains "$details" "SUMMARY-A"
  assert_contains "$details" "Discuss on GitHub"
  for body in BODY-A BODY-B BODY-C BODY-D; do assert_not_contains "$c" "$body"; done
  # Theme tags on A, B and D, none on C; data attributes on every row.
  assert_eq 3 "$(printf '%s' "$c" | grep -o 'class="tag"' | wc -l | tr -d ' ')" "three theme tags"
  assert_contains "$c" 'data-item-theme="Alpha" data-date="2026-01-03"'
  assert_contains "$c" 'data-item-theme="" data-date=""'
  # "Open all", hidden until the script shows it.
  assert_contains "$(printf '%s' "$c" | grep -o '<button[^>]*>Open all</button>')" "hidden"
}

test_one_doctype_first() {
  render knowledge
  assert_eq 1 "$(grep -c '<!doctype html>' "$PUB/index.html")" "one doctype"
  assert_eq '<!doctype html>' "$(grep -m1 . "$PUB/index.html")" "doctype first"
}
