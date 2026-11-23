#!/usr/bin/env bash
# Minimal test helpers, sourced by tests/run.sh into each test file.
#
# A test file defines functions named test_*; each runs in its own subshell
# with a fresh temporary directory in $TMP. An assertion that fails prints a
# message and returns 1, which fails that test.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TILE_ROOT="$REPO_ROOT/tile"                 # the tessl plugin
TILE="$TILE_ROOT/skills/site-setup"         # the runtime: core, adapters, scripts, templates

fail() { printf '    %s\n' "$*" >&2; return 1; }

assert_eq() { # expected actual [message]
  [ "$1" = "$2" ] || fail "${3:-assert_eq}: expected [$1], got [$2]"
}

assert_contains() { # haystack needle [message]
  case "$1" in *"$2"*) ;; *) fail "${3:-assert_contains}: [$2] not in [$1]";; esac
}

assert_not_contains() { # haystack needle [message]
  case "$1" in *"$2"*) fail "${3:-assert_not_contains}: [$2] found in output";; *) ;; esac
}

assert_file() { [ -f "$1" ] || fail "missing file: $1"; }
assert_no_path() { [ ! -e "$1" ] || fail "unexpected path: $1"; }

# Make a git repo in $1 with a deterministic identity.
make_repo() {
  mkdir -p "$1" && git -C "$1" init -q -b dev &&
  git -C "$1" config user.name "Test Author" &&
  git -C "$1" config user.email "author@example.com" &&
  git -C "$1" config commit.gpgsign false
}

# commit_at <repo> <iso-date> <message...>: commit everything at a fixed date.
commit_at() {
  local repo=$1 when=$2; shift 2
  git -C "$repo" add -A &&
  GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" \
    git -C "$repo" commit -q --allow-empty "$@"
}
