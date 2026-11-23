# Tests for tile/adapters/reference/python.
ADAPTER="$TILE/adapters/reference/python"

make_fixture() { # dir
  local d=$1
  mkdir -p "$d/pkg" "$d/tests" "$d/.hidden" "$d/site" "$d/venv" "$d/node_modules/x"
  : > "$d/pkg/__init__.py"
  cat > "$d/pkg/mod.py" <<'PY'
"""Module summary line."""

def public(a, b: int = 2, *args, key="k", **kw) -> str:
    """Public function doc."""

def _private():
    """Hidden."""

class Widget(Base):
    """Widget doc."""
    def run(self, speed: float = 1.0):
        """Run doc."""
    def _internal(self):
        """Nope."""

class _Hidden:
    """Nope."""
PY
  printf 'def only_func():\n    pass\n' > "$d/pkg/nodoc.py"
  printf '_x = 1\n' > "$d/pkg/empty.py"
  printf '"""t"""\ndef t(): pass\n' > "$d/tests/helper.py"
  printf '"""t"""\n' > "$d/pkg/test_mod.py"
  printf '"""h"""\n' > "$d/.hidden/h.py"
  printf '"""s"""\n' > "$d/site/s.py"
  printf '"""s"""\n' > "$d/venv/v.py"
  printf '"""s"""\n' > "$d/node_modules/x/n.py"
}

test_pages_paths_and_titles() {
  make_fixture "$TMP/p"
  out=$("$ADAPTER" "$TMP/p")
  assert_eq '["pkg/mod.md","pkg/nodoc.md"]' "$(jq -c '[.[].path]' <<<"$out")"
  assert_eq '["pkg.mod","pkg.nodoc"]' "$(jq -c '[.[].title]' <<<"$out")"
}

test_content_has_docstrings_and_signatures() {
  make_fixture "$TMP/p"
  c=$("$ADAPTER" "$TMP/p" | jq -r '.[] | select(.path=="pkg/mod.md") | .content')
  assert_contains "$c" "Module summary line."
  assert_contains "$c" '## `public(a, b: int = 2, *args, key='
  assert_contains "$c" '**kw) -> str`'
  assert_contains "$c" "Public function doc."
  assert_contains "$c" '## class `Widget`'
  assert_contains "$c" "Widget doc."
  assert_contains "$c" '### `run(self, speed: float = 1.0)`'
  assert_contains "$c" "Run doc."
}

test_private_names_excluded() {
  make_fixture "$TMP/p"
  c=$("$ADAPTER" "$TMP/p" | jq -r '.[].content')
  assert_not_contains "$c" "_private"
  assert_not_contains "$c" "_internal"
  assert_not_contains "$c" "_Hidden"
  assert_not_contains "$c" "Nope"
}

test_excluded_dirs_and_files() {
  make_fixture "$TMP/p"
  paths=$("$ADAPTER" "$TMP/p" | jq -r '.[].path')
  for bad in tests hidden site venv node_modules test_mod empty; do
    assert_not_contains "$paths" "$bad"
  done
}

test_no_python_gives_empty_array() {
  mkdir -p "$TMP/e" && echo hi > "$TMP/e/README.md"
  assert_eq '[]' "$("$ADAPTER" "$TMP/e" | jq -c .)"
}

test_syntax_error_skipped() {
  make_fixture "$TMP/p"
  echo 'def broken(:' > "$TMP/p/pkg/bad.py"
  "$ADAPTER" "$TMP/p" >"$TMP/out" 2>"$TMP/err"
  assert_eq '["pkg/mod.md","pkg/nodoc.md"]' "$(jq -c '[.[].path]' "$TMP/out")"
  assert_contains "$(cat "$TMP/err")" "bad.py"
}

test_code_never_executed() {
  mkdir -p "$TMP/p"
  cat > "$TMP/p/evil.py" <<PY
"""Evil."""
open("$TMP/marker", "w").write("ran")
def f():
    """F."""
PY
  out=$("$ADAPTER" "$TMP/p")
  assert_eq '["evil.md"]' "$(jq -c '[.[].path]' <<<"$out")"
  assert_no_path "$TMP/marker"
}
