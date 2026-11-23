#!/usr/bin/env bash
# timeline.sh <project-dir> [<since-YYYY-MM-DD>]
#
# Read the git graph of <project-dir> (HEAD and everything reachable from it) and
# print, to stdout, a JSON array of timeline events, oldest first:
#
#   {"date": "YYYY-MM-DD", "stage": "explored"|"decided"|"built"|"shipped",
#    "kind": <kind>, "path": <artefact path or tag>, "title": <str>,
#    "commit": <short sha>, "recent": <bool>}
#
# Kinds and their stages:
#   discovery-added  explored  a commit adds docs/discovery/NNNN-*.md
#   adr-added        decided   a commit adds docs/adr/NNNN-*.md
#   adr-revised      decided   a commit carries `Revises: <adr>`
#   note-consumed    decided   a commit carries `Consumed-By: <adr>` (path is the ADR)
#   plan-added       decided   a commit adds plans/NNNN-*.md
#   plan-abandoned   decided   a commit carries `Abandons: <plan>`
#   plan-completed   built     a commit carries `Completes: <plan>`
#   release          shipped   a tag points at a commit (path is the tag name)
#
# `title` is the artefact's front-matter `title`, read from the commit (or its
# parent when the commit deletes the file); otherwise the commit subject, or the
# tag name for releases. Each (kind, path) appears once, at its earliest commit.
# `recent` is true when date >= <since>; when <since> is omitted every event is
# recent. `Derives-From` adds no event: it links artefacts already listed.
# Prints `[]` for a repository with no matching history. Exits 2 if
# <project-dir> is not a git repository.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"

dir=${1:-}; since=${2:-}
if [ -z "$dir" ] || ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  echo "timeline.sh: not a git repository: ${dir:-<none>}" >&2; exit 2
fi
g() { git -C "$dir" "$@"; }
US=$(printf '\037')

# title_at <rev> <path> <fallback>
title_at() {
  local t
  t=$(g show "$1:$2" 2>/dev/null | { tmp=$(mktemp); cat > "$tmp"; frontmatter_get "$tmp" title; rm -f "$tmp"; }) || t=
  printf '%s' "${t:-$3}"
}

emit() { # seq date stage kind path title commit
  printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\n' "$@"
}

events() {
  g rev-parse --verify -q HEAD >/dev/null || return 0
  local seq=0 sha short day subject f v
  declare -A seq_of day_of
  while IFS=$US read -r sha short day subject; do
    seq=$((seq + 1)); seq_of[$sha]=$seq; day_of[$sha]=$day
    while IFS= read -r f; do
      case $f in
        docs/discovery/[0-9][0-9][0-9][0-9]-*.md)
          emit "$seq" "$day" explored discovery-added "$f" "$(title_at "$sha" "$f" "$subject")" "$short" ;;
        docs/adr/[0-9][0-9][0-9][0-9]-*.md)
          emit "$seq" "$day" decided adr-added "$f" "$(title_at "$sha" "$f" "$subject")" "$short" ;;
        plans/[0-9][0-9][0-9][0-9]-*.md)
          emit "$seq" "$day" decided plan-added "$f" "$(title_at "$sha" "$f" "$subject")" "$short" ;;
      esac
    done < <(g diff-tree --no-commit-id -r --root --diff-filter=A --name-only "$sha")
    for pair in Revises:adr-revised:decided Consumed-By:note-consumed:decided \
                Abandons:plan-abandoned:decided Completes:plan-completed:built; do
      IFS=: read -r key kind stage <<<"$pair"
      while IFS= read -r v; do
        [ -n "$v" ] || continue
        local t; t=$(title_at "$sha" "$v" ""); [ -n "$t" ] || t=$(title_at "$sha^" "$v" "$subject")
        emit "$seq" "$day" "$stage" "$kind" "$v" "$t" "$short"
      done < <(g log -1 --format="%(trailers:key=$key,valueonly)" "$sha")
    done
  done < <(TZ=UTC g log --reverse --date-order --date=format-local:%Y-%m-%d \
             --format="%H${US}%h${US}%cd${US}%s" HEAD)
  local tag c
  while IFS= read -r tag; do
    c=$(g rev-list -n1 "$tag")
    [ -n "${seq_of[$c]:-}" ] || continue
    emit "${seq_of[$c]}.5" "${day_of[$c]}" shipped release "$tag" "$tag" "$(g rev-parse --short "$c")"
  done < <(g tag --list)
}

events | jq -R -s --arg since "$since" '
  split("\n") | map(select(length > 0) | split("\u001f")
    | {seq: (.[0] | tonumber), date: .[1], stage: .[2], kind: .[3], path: .[4], title: .[5], commit: .[6]})
  | sort_by([.date, .seq])
  | unique_by([.kind, .path]) | sort_by([.date, .seq])
  | map(.recent = ($since == "" or .date >= $since) | del(.seq))'
