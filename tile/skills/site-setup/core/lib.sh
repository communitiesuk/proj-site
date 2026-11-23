#!/usr/bin/env bash
# Shared helpers for the site core. Source this file; it defines functions only.
#
# Functions:
#   yaml_get <file> <key>     Print the value of <key> from a restricted-YAML file.
#                             <key> is `name` for top level or `parent.child` for one
#                             level of nesting. Surrounding quotes are removed; an
#                             inline list `[a, b]` is printed as "a b". Prints nothing
#                             (exit 0) when the key is absent. Comments (` # ...`) are
#                             ignored.
#   iso_week <YYYY-MM-DD>     Print the ISO week-numbering year and week, `%G-W%V`
#                             (e.g. 2026-W01). Works with GNU and BSD date.
#   frontmatter_get <file> <key>
#                             Print a top-level scalar from a Markdown file's YAML
#                             front matter (between the first two `---` lines).

_strip_value() { # strip comment, whitespace and surrounding quotes from stdin
  sed -e 's/[[:space:]]#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      -e 's/^"\(.*\)"$/\1/' -e "s/^'\\(.*\\)'\$/\\1/"
}

yaml_get() {
  local file=$1 key=$2 parent= child=$2
  case $key in *.*) parent=${key%%.*}; child=${key#*.};; esac
  [ -f "$file" ] || return 0
  local raw
  raw=$(awk -v parent="$parent" -v child="$child" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      indent = match($0, /[^ ]/) - 1
      line = substr($0, indent + 1)
      k = line; sub(/:.*/, "", k)
      v = line; if (index(v, ":")) { sub(/^[^:]*:/, "", v) } else { v = "" }
      if (indent == 0) {
        cur = k
        if (parent == "" && k == child) { print v; exit }
      } else if (parent != "" && cur == parent && k == child) { print v; exit }
    }' "$file" | _strip_value)
  case $raw in
    \[*\]) raw=${raw#[}; raw=${raw%]}
           printf '%s\n' "$raw" | tr ',' '\n' | _strip_value | paste -sd ' ' - ;;
    *) printf '%s\n' "$raw" | sed '/^$/d' ;;
  esac
}

iso_week() {
  date -u -d "$1" +%G-W%V 2>/dev/null || date -u -j -f %F "$1" +%G-W%V
}

frontmatter_get() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 { k = $0; sub(/:.*/, "", k); if (k == key) { v = $0; sub(/^[^:]*:/, "", v); print v; exit } }
  ' "$1" | _strip_value
}
