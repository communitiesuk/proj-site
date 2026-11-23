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

yaml_get() { :; }
iso_week() { :; }
frontmatter_get() { :; }
