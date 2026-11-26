#!/usr/bin/env bash
# build.sh <project-dir> <out-dir> [--no-render]
#
# Build an opted-in project's site.
#
# Reads <project-dir>/site/project.yaml and assembles a Hugo source tree in
# <out-dir>/src (never committed), then renders it into <out-dir>/public with
# Hugo unless --no-render is given.
#
# The source tree (committed folders keep their names; the build writes the
# section folders that set the web addresses):
#   src/hugo.toml               generated: title from `name`, baseURL from
#                               $SITE_BASE_URL (default "/"), menu of enabled sections
#                               in the order Overview, Guides, Docs, Weeknotes,
#                               Latest updates, Coming next, each named explicitly
#   src/layouts/                copied from tile/core/layouts, each `*.html.txt`
#                               renamed to `*.html` (the tessl registry drops .html)
#   src/static/                 copied from tile/core/static, where it exists
#   src/content/_index.md       from site/content/overview.md (title "Overview")
#   src/content/guides/         site/content/guides/** — only for knowledge|both
#   src/content/docs/           site/content/docs/** (hand-written; knowledge|both) and
#                               docs/reference/ pages from each `languages` adapter
#                               (code|both). Enabled for code|both, and for knowledge
#                               when site/content/docs/ holds a page other than _index.md
#   src/content/weeknotes/      site/content/summaries/*.md
#   src/content/updates/        site/content/changes/*.md, each with `week`
#                               (%G-W%V of its date), `ghrefs` (its `refs`, each
#                               {"label", "url"}: the issue page for #N, the blob URL
#                               for a path present at HEAD, no url for one absent) and,
#                               unless $SITE_OFFLINE=1, `pr` (number of the PR that
#                               added it, via gh) added
#   src/content/coming-next/    section page; items in src/data/upcoming.json
#   src/data/timeline.json      from timeline.sh, `recent` since the latest weeknote's
#                               `period_end` (all recent when there is no weeknote)
#   src/data/upcoming.json      from the `upcoming.source` adapter
#
# Every section's index title is its tab name. The body of every copied page
# (overview, guides, hand-written docs, updates, weeknotes; not generated
# reference) goes through `link_github` (lib.sh), linking #N, docs/ and plans/
# paths and commit IDs to GitHub.
#
# Adapters are resolved as <root>/<kind>/<name>.sh (run with bash), <name>.py
# (run with python3), or an executable <name>, in that order; the registry
# drops extensionless files and the executable bit.
#
# Every section dir gets an _index.md if none was supplied. Environment:
#   SITE_GH       gh command (default gh); SITE_OFFLINE=1 skips PR lookups
#   SITE_ADAPTERS adapters root (default tile/adapters next to this script)
#   HUGO          hugo command (default hugo)
#
# Exits 2 on a usage error or a missing/invalid project.yaml (content_type
# not knowledge|code|both); exits non-zero if an adapter or Hugo fails, with
# the failing step named on stderr.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"

usage() { echo "usage: build.sh <project-dir> <out-dir> [--no-render]" >&2; exit 2; }
[ $# -ge 2 ] || usage
project=$(cd "$1" 2>/dev/null && pwd) || { echo "build.sh: no such project dir: $1" >&2; exit 2; }
out=$2; render=1
[ "${3:-}" = "--no-render" ] && render=0
GH=${SITE_GH:-gh}; HUGO=${HUGO:-hugo}
ADAPTERS=${SITE_ADAPTERS:-$here/../adapters}

cfg="$project/site/project.yaml"
[ -f "$cfg" ] || { echo "build.sh: missing $cfg (site/project.yaml)" >&2; exit 2; }
name=$(yaml_get "$cfg" name); repo=$(yaml_get "$cfg" repository)
ctype=$(yaml_get "$cfg" content_type); langs=$(yaml_get "$cfg" languages)
upsrc=$(yaml_get "$cfg" upcoming.source)
case $ctype in knowledge|code|both) ;; *)
  echo "build.sh: content_type must be knowledge, code or both (got '${ctype}') in site/project.yaml" >&2; exit 2;;
esac

src="$out/src"; content="$src/content"; sitec="$project/site/content"
rm -rf "$src"; mkdir -p "$content" "$src/data"
cp -R "$here/layouts" "$src/layouts"
find "$src/layouts" -name '*.html.txt' | while IFS= read -r f; do mv "$f" "${f%.txt}"; done
[ -d "$here/static" ] && cp -R "$here/static" "$src/static"

# run_adapter <kind> <name>: run an adapter in the project dir; 127 if absent.
run_adapter() {
  local base="$ADAPTERS/$1/$2"
  if [ -f "$base.sh" ]; then (cd "$project" && bash "$base.sh" "$project")
  elif [ -f "$base.py" ]; then (cd "$project" && python3 "$base.py" "$project")
  elif [ -x "$base" ]; then (cd "$project" && "$base" "$project")
  else return 127; fi
}

section_index() { # dir title
  [ -f "$1/_index.md" ] || printf -- '---\ntitle: %s\n---\n' "$2" > "$1/_index.md"
}

# link_pages <dir>: run link_github over every Markdown file under <dir>, in place.
link_pages() {
  find "$1" -type f -name '*.md' | while IFS= read -r f; do
    link_github "$repo" "$project" < "$f" > "$f.linked" && mv "$f.linked" "$f"
  done
}

# ghrefs <entry>: its front-matter `refs` (an inline list) as a JSON array of
# {"label", "url"}; nothing when it has none or they do not parse.
ghrefs() {
  local raw ref url out='[]'
  raw=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
    NR > 1 && /^refs:/ { sub(/^refs:[[:space:]]*/, ""); print; exit }' "$1")
  [ -n "$raw" ] && printf '%s' "$raw" | jq -e 'type == "array"' >/dev/null 2>&1 || return 0
  while IFS= read -r ref; do
    url=
    case $ref in
      \#[1-9]*) [ -n "$repo" ] && url="https://github.com/$repo/issues/${ref#\#}" ;;
      *) [ -n "$repo" ] && git -C "$project" cat-file -e "HEAD:$ref" 2>/dev/null \
           && url="https://github.com/$repo/blob/HEAD/$ref" ;;
    esac
    out=$(printf '%s' "$out" | jq -c --arg l "$ref" --arg u "$url" '. + [if $u == "" then {label: $l} else {label: $l, url: $u} end]')
  done < <(printf '%s' "$raw" | jq -r '.[] | tostring')
  printf '%s' "$out"
}

# Overview.
if [ -f "$sitec/overview.md" ]; then link_github "$repo" "$project" < "$sitec/overview.md" > "$content/_index.md"
else printf -- '---\ntitle: Overview\n---\n' > "$content/_index.md"; fi

# Latest updates: per-PR entries with week and (online) PR number.
mkdir -p "$content/updates"
for f in "$sitec"/changes/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f"); dest="$content/updates/$base"
  [ "$base" = "_index.md" ] && { cp "$f" "$dest"; continue; }
  day=$(frontmatter_get "$f" date); day=${day:0:10}
  extra="week: \"$(iso_week "$day")\""
  refs=$(ghrefs "$f"); [ -z "$refs" ] || extra="$extra
ghrefs: $refs"
  if [ "${SITE_OFFLINE:-0}" != 1 ] && [ -n "$repo" ]; then
    sha=$(git -C "$project" log --diff-filter=A --format=%H -1 -- "site/content/changes/$base" 2>/dev/null || true)
    if [ -n "$sha" ]; then
      pr=$("$GH" api "repos/$repo/commits/$sha/pulls" --jq '.[0].number // empty' 2>/dev/null || true)
      [ -n "$pr" ] && extra="$extra
pr: $pr"
    fi
  fi
  EXTRA=$extra awk 'NR == 1 { print; next } !done && $0 == "---" { print ENVIRON["EXTRA"]; done = 1 } { print }' "$f" \
    | link_github "$repo" "$project" > "$dest"
done
section_index "$content/updates" "Latest updates"

# Weeknotes.
mkdir -p "$content/weeknotes"
latest_end=
for f in "$sitec"/summaries/*.md; do
  [ -e "$f" ] || continue
  cp "$f" "$content/weeknotes/"
  [ "$(basename "$f")" = "_index.md" ] && continue
  link_github "$repo" "$project" < "$f" > "$content/weeknotes/$(basename "$f")"
  e=$(frontmatter_get "$f" period_end)
  [ -z "$e" ] || [[ "$e" < "$latest_end" ]] || latest_end=$e
done
section_index "$content/weeknotes" Weeknotes

# Timeline.
bash "$here/timeline.sh" "$project" "$latest_end" > "$src/data/timeline.json" \
  || { echo "build.sh: timeline failed" >&2; exit 1; }

# Coming next.
mkdir -p "$content/coming-next"; section_index "$content/coming-next" "Coming next"
if [ -n "$upsrc" ]; then
  rc=0; run_adapter upcoming "$upsrc" > "$src/data/upcoming.json" || rc=$?
  [ "$rc" -ne 127 ] || { echo "build.sh: upcoming adapter not found: $upsrc" >&2; exit 1; }
  [ "$rc" -eq 0 ] || { echo "build.sh: upcoming adapter '$upsrc' failed" >&2; exit 1; }
else
  echo '[]' > "$src/data/upcoming.json"
fi

# Guides (knowledge|both).
guides=0; docs=0
if [ "$ctype" != code ]; then
  guides=1; mkdir -p "$content/guides"
  [ -d "$sitec/guides" ] && cp -R "$sitec/guides/." "$content/guides/" && link_pages "$content/guides"
  section_index "$content/guides" Guides
fi

# Docs: hand-written pages (knowledge|both) and reference (code|both).
has_docs=$(find "$sitec/docs" -type f -name '*.md' ! -name '_index.md' 2>/dev/null | head -1)
if [ "$ctype" != code ] && [ -n "$has_docs" ]; then
  docs=1; mkdir -p "$content/docs"; cp -R "$sitec/docs/." "$content/docs/"; link_pages "$content/docs"
fi
if [ "$ctype" != knowledge ]; then
  docs=1; mkdir -p "$content/docs/reference"
  for lang in $langs; do
    rc=0; pages=$(run_adapter reference "$lang") || rc=$?
    [ "$rc" -ne 127 ] || { echo "build.sh: reference adapter not found: $lang" >&2; exit 1; }
    [ "$rc" -eq 0 ] || { echo "build.sh: reference adapter '$lang' failed" >&2; exit 1; }
    printf '%s' "$pages" | jq -c '.[]' | while IFS= read -r page; do
      p=$(printf '%s' "$page" | jq -r .path)
      case $p in /*|*..*) echo "build.sh: reference adapter '$lang' gave unsafe path $p" >&2; exit 1;; esac
      mkdir -p "$(dirname "$content/docs/reference/$p")"
      printf '%s' "$page" | jq -r '"---\ntitle: " + (.title | tojson) + "\n---\n" + .content' \
        > "$content/docs/reference/$p"
    done
  done
  section_index "$content/docs/reference" Reference
fi
[ "$docs" = 1 ] && section_index "$content/docs" Docs

# Tabs, in order: "address|name".
menu="/|Overview"
[ "$guides" = 1 ] && menu="$menu;/guides/|Guides"
[ "$docs" = 1 ] && menu="$menu;/docs/|Docs"
menu="$menu;/weeknotes/|Weeknotes;/updates/|Latest updates;/coming-next/|Coming next"

# Hugo config.
{
  printf 'baseURL = "%s"\ntitle = %s\n' "${SITE_BASE_URL:-/}" "$(jq -Rn --arg n "${name:-Project}" '$n')"
  printf 'disableKinds = ["taxonomy", "term", "RSS", "sitemap"]\n'
  printf '[params]\n  repository = "%s"\n  contentType = "%s"\n' "$repo" "$ctype"
  w=0
  IFS=';'; for m in $menu; do
    w=$((w + 1))
    printf '[[menus.main]]\n  name = "%s"\n  pageRef = "%s"\n  weight = %d\n' "${m#*|}" "${m%%|*}" "$w"
  done; unset IFS
} > "$src/hugo.toml"

if [ "$render" = 1 ]; then
  "$HUGO" --quiet --source "$src" --destination "$(cd "$out" && pwd)/public" \
    || { echo "build.sh: hugo failed" >&2; exit 1; }
fi
