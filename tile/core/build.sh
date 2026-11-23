#!/usr/bin/env bash
# build.sh <project-dir> <out-dir> [--no-render]
#
# Build an opted-in project's site.
#
# Reads <project-dir>/site/project.yaml and assembles a Hugo source tree in
# <out-dir>/src (never committed), then renders it into <out-dir>/public with
# Hugo unless --no-render is given.
#
# The source tree:
#   src/hugo.toml               generated: title from `name`, baseURL from
#                               $SITE_BASE_URL (default "/"), menu of enabled sections
#   src/layouts/                copied from tile/core/layouts, each `*.html.txt`
#                               renamed to `*.html` (the tessl registry drops .html)
#   src/content/_index.md       from site/content/overview.md (title "Overview")
#   src/content/changes/        site/content/changes/*.md, each with `week`
#                               (%G-W%V of its date) and, unless $SITE_OFFLINE=1,
#                               `pr` (number of the PR that added it, via gh) added
#   src/content/summaries/      site/content/summaries/*.md
#   src/content/upcoming/       section page; items in src/data/upcoming.json
#   src/content/docs/           site/content/docs/** — only for knowledge|both
#   src/content/reference/      pages from each `languages` adapter — only for code|both
#   src/data/timeline.json      from timeline.sh, `recent` since the latest summary's
#                               `period_end` (all recent when there is no summary)
#   src/data/upcoming.json      from the `upcoming.source` adapter
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

# Overview.
if [ -f "$sitec/overview.md" ]; then cp "$sitec/overview.md" "$content/_index.md"
else printf -- '---\ntitle: Overview\n---\n' > "$content/_index.md"; fi

# Changes: per-PR entries with week and (online) PR number.
mkdir -p "$content/changes"
for f in "$sitec"/changes/*.md; do
  [ -e "$f" ] || continue
  base=$(basename "$f"); dest="$content/changes/$base"
  [ "$base" = "_index.md" ] && { cp "$f" "$dest"; continue; }
  day=$(frontmatter_get "$f" date); day=${day:0:10}
  extra="week: \"$(iso_week "$day")\""
  if [ "${SITE_OFFLINE:-0}" != 1 ] && [ -n "$repo" ]; then
    sha=$(git -C "$project" log --diff-filter=A --format=%H -1 -- "site/content/changes/$base" 2>/dev/null || true)
    if [ -n "$sha" ]; then
      pr=$("$GH" api "repos/$repo/commits/$sha/pulls" --jq '.[0].number // empty' 2>/dev/null || true)
      [ -n "$pr" ] && extra="$extra
pr: $pr"
    fi
  fi
  EXTRA=$extra awk 'NR == 1 { print; next } !done && $0 == "---" { print ENVIRON["EXTRA"]; done = 1 } { print }' "$f" > "$dest"
done
section_index "$content/changes" Changes

# Summaries.
mkdir -p "$content/summaries"
latest_end=
for f in "$sitec"/summaries/*.md; do
  [ -e "$f" ] || continue
  cp "$f" "$content/summaries/"
  [ "$(basename "$f")" = "_index.md" ] && continue
  e=$(frontmatter_get "$f" period_end)
  [ -z "$e" ] || [[ "$e" < "$latest_end" ]] || latest_end=$e
done
section_index "$content/summaries" Summaries

# Timeline.
bash "$here/timeline.sh" "$project" "$latest_end" > "$src/data/timeline.json" \
  || { echo "build.sh: timeline failed" >&2; exit 1; }

# Upcoming.
mkdir -p "$content/upcoming"; section_index "$content/upcoming" Upcoming
if [ -n "$upsrc" ]; then
  rc=0; run_adapter upcoming "$upsrc" > "$src/data/upcoming.json" || rc=$?
  [ "$rc" -ne 127 ] || { echo "build.sh: upcoming adapter not found: $upsrc" >&2; exit 1; }
  [ "$rc" -eq 0 ] || { echo "build.sh: upcoming adapter '$upsrc' failed" >&2; exit 1; }
else
  echo '[]' > "$src/data/upcoming.json"
fi

# Docs (knowledge|both).
menu="overview changes summaries upcoming"
if [ "$ctype" != code ]; then
  mkdir -p "$content/docs"
  [ -d "$sitec/docs" ] && cp -R "$sitec/docs/." "$content/docs/"
  section_index "$content/docs" Docs; menu="$menu docs"
fi

# Reference (code|both).
if [ "$ctype" != knowledge ]; then
  mkdir -p "$content/reference"
  for lang in $langs; do
    rc=0; pages=$(run_adapter reference "$lang") || rc=$?
    [ "$rc" -ne 127 ] || { echo "build.sh: reference adapter not found: $lang" >&2; exit 1; }
    [ "$rc" -eq 0 ] || { echo "build.sh: reference adapter '$lang' failed" >&2; exit 1; }
    printf '%s' "$pages" | jq -c '.[]' | while IFS= read -r page; do
      p=$(printf '%s' "$page" | jq -r .path)
      case $p in /*|*..*) echo "build.sh: reference adapter '$lang' gave unsafe path $p" >&2; exit 1;; esac
      mkdir -p "$(dirname "$content/reference/$p")"
      printf '%s' "$page" | jq -r '"---\ntitle: " + (.title | tojson) + "\n---\n" + .content' \
        > "$content/reference/$p"
    done
  done
  section_index "$content/reference" Reference; menu="$menu reference"
fi

# Hugo config.
{
  printf 'baseURL = "%s"\ntitle = %s\n' "${SITE_BASE_URL:-/}" "$(jq -Rn --arg n "${name:-Project}" '$n')"
  printf 'disableKinds = ["taxonomy", "term", "RSS", "sitemap"]\n'
  printf '[params]\n  repository = "%s"\n  contentType = "%s"\n' "$repo" "$ctype"
  w=0
  for m in $menu; do
    w=$((w + 1))
    case $m in overview) url=/; t=Overview;; *) url="/$m/"; t=$(printf '%s' "$m" | awk '{print toupper(substr($0,1,1)) substr($0,2)}');; esac
    printf '[[menus.main]]\n  name = "%s"\n  pageRef = "%s"\n  weight = %d\n' "$t" "$url" "$w"
  done
} > "$src/hugo.toml"

if [ "$render" = 1 ]; then
  "$HUGO" --quiet --source "$src" --destination "$(cd "$out" && pwd)/public" \
    || { echo "build.sh: hugo failed" >&2; exit 1; }
fi
