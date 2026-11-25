#!/usr/bin/env bash
# Run every tests/test_*.sh. Each test_* function runs in its own subshell
# with a fresh $TMP, and without the caller's GITHUB_* environment variables:
# in GitHub Actions these describe the run itself (GITHUB_HEAD_REF names the
# pull request's branch), and a test that wants one sets it explicitly.
# Exits non-zero if any test fails.
#
# Usage: tests/run.sh [pattern]   # only files whose name contains pattern
set -u
here=$(cd "$(dirname "$0")" && pwd)
pass=0; failed=0
for file in "$here"/test_*.sh; do
  [ -e "$file" ] || continue
  case "$(basename "$file")" in *"${1:-}"*) ;; *) continue;; esac
  for t in $(bash -c ". '$here/lib.sh'; . '$file'; declare -F" | awk '{print $3}' | grep '^test_'); do
    tmp=$(mktemp -d)
    # A separate bash process: `set -e` is ignored inside an `if` condition,
    # including in subshells, but not in a child process.
    if (cd "$tmp" && TMP="$tmp" bash -c 'set -e; . "$1"; . "$2"; "$3"' _ "$here/lib.sh" "$file" "$t") >"$tmp.log" 2>&1; then
      pass=$((pass+1)); printf 'ok   %s %s\n' "$(basename "$file")" "$t"
    else
      failed=$((failed+1)); printf 'FAIL %s %s\n' "$(basename "$file")" "$t"; sed 's/^/     /' "$tmp.log"
    fi
    rm -rf "$tmp" "$tmp.log"
  done
done
printf '\n%d passed, %d failed\n' "$pass" "$failed"
[ "$failed" -eq 0 ]
