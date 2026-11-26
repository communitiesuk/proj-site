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
