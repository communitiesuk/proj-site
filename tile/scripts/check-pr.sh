#!/usr/bin/env bash
# check-pr.sh - PR check for the project site; run from the project root.
#
# Usage:
#   check-pr.sh --base <trunk-ref> [--head <ref>] [--now <ISO-8601 UTC>]
#               [--pr <number>] [--repo <owner/name>]
#   check-pr.sh --due-week [--now <ISO-8601 UTC>]
#
# --head defaults to HEAD; --now defaults to the current UTC time.
#
# Check 1 (change entry): `git diff <base>...<head>` must ADD (status A) at
#   least one file under site/content/changes/. Otherwise the failure message
#   names site/content/changes/<YYYY-MM-DD>-<branch-slug>.md and the
#   `site-writing` skill. The branch is $GITHUB_HEAD_REF when set (in Actions
#   the checkout is a detached merge commit), else <head>'s branch name.
#
# Check 2 (summary due): the due summary is
#   site/content/summaries/<%G-W%V>.md for the ISO week containing the most
#   recent Thursday 00:00 UTC at or before --now. It passes if the file exists
#   in the <base> tree, or the PR diff adds/modifies it, or another open PR
#   (listed via `$SITE_GH pr list --repo R --state open --json number,files`,
#   excluding --pr) changes it. If gh is unavailable or fails, a warning goes
#   to stderr and the file is treated as not found. Otherwise the failure
#   message names the due file and the `site-writing` skill.
#
# --due-week prints the due ISO week (e.g. 2026-W01) and exits 0.
#
# Dates are computed with pure shell arithmetic (no GNU/BSD date flags).
#
# Environment: SITE_GH overrides the gh command (default `gh`).
# Exit status: 0 both checks pass; 1 any check failed (all failure messages,
#   together, on stderr); 2 usage error.
set -u

usage() {
  echo "usage: check-pr.sh --base <ref> [--head <ref>] [--now <ts>] [--pr <n>] [--repo <o/n>]" >&2
  echo "       check-pr.sh --due-week [--now <ts>]" >&2
  exit 2
}

# days_from_civil Y M D -> days since 1970-01-01 (proleptic Gregorian).
days_from_civil() {
  local y=$1 m=$((10#$2)) d=$((10#$3)) era yoe doy doe
  [ "$m" -le 2 ] && y=$((y - 1))
  era=$(( (y >= 0 ? y : y - 399) / 400 ))
  yoe=$((y - era * 400))
  doy=$(( (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1 ))
  doe=$((yoe * 365 + yoe / 4 - yoe / 100 + doy))
  echo $((era * 146097 + doe - 719468))
}

# civil_from_days N -> "Y M D"
civil_from_days() {
  local z=$(($1 + 719468)) era doe yoe y doy mp d m
  era=$(( (z >= 0 ? z : z - 146096) / 146097 ))
  doe=$((z - era * 146097))
  yoe=$(( (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365 ))
  y=$((yoe + era * 400))
  doy=$((doe - (365 * yoe + yoe / 4 - yoe / 100)))
  mp=$(( (5 * doy + 2) / 153 ))
  d=$((doy - (153 * mp + 2) / 5 + 1))
  m=$((mp < 10 ? mp + 3 : mp - 9))
  [ "$m" -le 2 ] && y=$((y + 1))
  echo "$y $m $d"
}

# due_week <ts> -> "<ISO year>-W<nn>" of the most recent Thursday at or before ts.
due_week() {
  local ts=$1 y m d days dow back thu ty tm td jan1 doy
  case "$ts" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) ;;
    *) echo "check-pr.sh: bad --now: $ts" >&2; exit 2;;
  esac
  y=${ts:0:4}; m=${ts:5:2}; d=${ts:8:2}
  days=$(days_from_civil "$y" "$m" "$d")
  dow=$(( (days % 7 + 7 + 3) % 7 + 1 ))   # Mon=1 .. Sun=7; 1970-01-01 is Thu
  back=$(( (dow - 4 + 7) % 7 ))
  thu=$((days - back))
  read -r ty tm td <<<"$(civil_from_days "$thu")"
  jan1=$(days_from_civil "$ty" 1 1)
  doy=$((thu - jan1 + 1))
  # A Thursday's ISO year is its calendar year.
  printf '%d-W%02d\n' "$ty" $(( (doy - 1) / 7 + 1 ))
}

base=""; head=HEAD; now=""; pr=""; repo=""; due_only=0
while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || usage; base=$2; shift 2;;
    --head) [ $# -ge 2 ] || usage; head=$2; shift 2;;
    --now)  [ $# -ge 2 ] || usage; now=$2; shift 2;;
    --pr)   [ $# -ge 2 ] || usage; pr=$2; shift 2;;
    --repo) [ $# -ge 2 ] || usage; repo=$2; shift 2;;
    --due-week) due_only=1; shift;;
    *) usage;;
  esac
done
[ -n "$now" ] || now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [ "$due_only" = 1 ]; then due_week "$now"; exit 0; fi
[ -n "$base" ] || usage

week=$(due_week "$now")
summary="site/content/summaries/$week.md"
failures=""
fail_msg() { failures="$failures$1"$'\n'; }

# Check 1: the PR adds a change entry.
added=$(git diff --name-status --diff-filter=A "$base...$head") || exit 2
if ! printf '%s\n' "$added" | awk -F'\t' '$1=="A" && $2 ~ /^site\/content\/changes\//{f=1} END{exit !f}'; then
  branch=$(git rev-parse --abbrev-ref "$head" 2>/dev/null || echo "$head")
  slug=$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n-' '-')
  fail_msg "FAIL: this PR adds no file under site/content/changes/. Add site/content/changes/${now:0:10}-$slug.md (use the site-writing skill)."
fi

# Check 2: the due summary exists on the trunk, in this PR, or in another open PR.
found=0
git cat-file -e "$base:$summary" 2>/dev/null && found=1
if [ "$found" = 0 ] &&
   git diff --name-only --diff-filter=AM "$base...$head" | grep -qxF "$summary"; then
  found=1
fi
if [ "$found" = 0 ]; then
  gh_cmd=${SITE_GH:-gh}
  args=(pr list)
  [ -z "$repo" ] || args+=(--repo "$repo")
  args+=(--state open --json number,files)
  if json=$($gh_cmd "${args[@]}" 2>/dev/null) && [ -n "$json" ]; then
    if printf '%s' "$json" | jq -e --arg pr "$pr" --arg f "$summary" \
        'any(.[]; (.number|tostring) != $pr and any((.files // [])[]; .path == $f))' >/dev/null 2>&1; then
      found=1
    fi
  else
    echo "warning: could not list open PRs with '$gh_cmd'; treating $summary as not found elsewhere" >&2
  fi
fi
if [ "$found" = 0 ]; then
  fail_msg "FAIL: summary $week is due but $summary is not on $base, in this PR, or in another open PR. Write it with the site-writing skill."
fi

if [ -n "$failures" ]; then printf '%s' "$failures" >&2; exit 1; fi
exit 0
