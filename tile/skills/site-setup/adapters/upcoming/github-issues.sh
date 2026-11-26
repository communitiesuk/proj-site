#!/usr/bin/env bash
# Upcoming-work adapter: open GitHub issues.
#
# Usage: github-issues <project-dir>
#
# Reads `repository` from <project-dir>/site/project.yaml (a `key: value`
# line); falls back to `gh repo view --json nameWithOwner` when absent.
# Lists open issues (up to 100) and writes a JSON array to stdout:
#   [{"title": str, "ref": "#<number>", "state": "open", "theme": str,
#     "summary": str, "date": "YYYY-MM-DD"}]
# `theme` is the first label named `theme:<x>`, prefix removed and trimmed,
# else "". `summary` is the issue body's section headed `## Site summary`:
# the text from the line after that heading up to the next heading or the
# end, trimmed; "" when there is no such heading. Nothing else from the body
# is output. `date` is the day the issue was opened (UTC), the first ten
# characters of `createdAt`. An empty issue list gives [].
#
# Env: SITE_GH  the gh command to run (default: gh); tests substitute a stub.
# Exit: non-zero with a message on stderr when gh fails.
set -euo pipefail
gh=${SITE_GH:-gh}
yaml="$1/site/project.yaml"

repo=
[ -f "$yaml" ] && repo=$(sed -n 's/^repository:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$yaml" | head -n1)
if [ -z "$repo" ]; then
  repo=$("$gh" repo view --json nameWithOwner | jq -r .nameWithOwner) || {
    echo "github-issues: cannot determine repository" >&2; exit 1; }
fi

issues=$("$gh" issue list --repo "$repo" --state open --limit 100 \
  --json number,title,state,labels,url,body,createdAt) || {
  echo "github-issues: gh failed listing issues for $repo" >&2; exit 1; }

printf '%s\n' "$issues" | jq '
# The text of the body section headed "## Site summary", up to the next heading.
def site_summary:
  (. // "") | gsub("\r"; "") | split("\n") as $l
  | (first(range(0; $l | length) | select($l[.] | test("^##[ \t]+Site summary[ \t]*$"; "i"))) // null) as $i
  | if $i == null then "" else
      $l[$i + 1:] as $r
      | (first(range(0; $r | length) | select($r[.] | test("^#{1,6}[ \t]"))) // ($r | length)) as $e
      | $r[:$e] | join("\n") | gsub("^\\s+|\\s+$"; "")
    end;
[.[] | {
  title,
  ref: "#\(.number)",
  state: (.state | ascii_downcase),
  theme: (first(.labels[].name | select(startswith("theme:")) | ltrimstr("theme:") | gsub("^\\s+|\\s+$"; "")) // ""),
  summary: (.body | site_summary),
  date: ((.createdAt // "")[:10])
}]'
