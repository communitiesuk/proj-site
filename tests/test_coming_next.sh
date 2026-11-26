# Tests for the Coming next controls' arrange() (core/static/coming-next.js),
# run under Node. The DOM wiring is checked in a browser (plan 0003).

JS="$TILE/core/static/coming-next.js"

# Items as step 5 renders them (D, A, B, C), plus E: same date as B, later.
ITEMS='[{"id":"D","theme":"Alpha","date":"2026-01-02","index":0},
        {"id":"A","theme":"Alpha","date":"2026-01-03","index":1},
        {"id":"B","theme":"Beta","date":"2026-01-01","index":2},
        {"id":"C","theme":"","date":"","index":3},
        {"id":"E","theme":"Beta","date":"2026-01-01","index":4}]'

# arranged <options-json>: the groups as "Theme:ids", "*" for ungrouped and
# "-" for no theme, space-separated.
arranged() {
  command -v node >/dev/null || { echo "node is required for the Coming next tests"; return 1; }
  node -e '
    const { arrange } = require(process.argv[1]);
    const groups = arrange(JSON.parse(process.argv[2]), JSON.parse(process.argv[3]));
    process.stdout.write(groups.map(g =>
      (g.theme === null ? "*" : g.theme === "" ? "-" : g.theme) + ":" + g.items.map(i => i.id).join(",")
    ).join(" "));
  ' "$JS" "$ITEMS" "$1"
}

test_default_is_grouped_oldest_first() {
  assert_eq "Alpha:D,A Beta:B,E -:C" "$(arranged '{"group":true,"order":"oldest","excluded":[]}')"
}

test_ungrouped_orders_by_date_undated_last() {
  assert_eq "*:B,E,D,A,C" "$(arranged '{"group":false,"order":"oldest","excluded":[]}')"
  assert_eq "*:A,D,B,E,C" "$(arranged '{"group":false,"order":"newest","excluded":[]}')"
}

test_grouped_newest_first() {
  assert_eq "Alpha:A,D Beta:B,E -:C" "$(arranged '{"group":true,"order":"newest","excluded":[]}')"
}

test_excluding_themes() {
  assert_eq "Alpha:D,A -:C" "$(arranged '{"group":true,"order":"oldest","excluded":["Beta"]}')"
  assert_eq "Alpha:D,A Beta:B,E" "$(arranged '{"group":true,"order":"oldest","excluded":[""]}')"
  assert_eq "" "$(arranged '{"group":true,"order":"oldest","excluded":["Alpha","Beta",""]}')"
}

test_every_control_at_once() {
  assert_eq "*:B,E,C" "$(arranged '{"group":false,"order":"newest","excluded":["Alpha"]}')"
}
