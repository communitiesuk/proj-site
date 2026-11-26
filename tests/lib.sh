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

# --- site fixtures (test_core.sh, test_layouts.sh) ------------------------

# A project repo with a known trailer chain:
#   01-01 add discovery note       01-02 add ADR        01-03 consume note
#   01-04 add plan                 01-06 complete plan, tag v0.1.0
#   01-08 revise ADR
make_chain_repo() {
  local r=$1
  make_repo "$r"
  mkdir -p "$r/docs/discovery" "$r/docs/adr" "$r/plans"
  printf -- '---\ntitle: An idea\n---\n' > "$r/docs/discovery/0001-idea.md"
  commit_at "$r" 2026-01-01T10:00:00Z -m "Add discovery note"
  printf -- '---\ntitle: Which choice?\n---\nv1\n' > "$r/docs/adr/0001-choice.md"
  commit_at "$r" 2026-01-02T10:00:00Z -m "Add ADR 0001"
  git -C "$r" rm -q docs/discovery/0001-idea.md
  commit_at "$r" 2026-01-03T10:00:00Z -m "Remove consumed note" -m "Consumed-By: docs/adr/0001-choice.md"
  printf -- '---\ntitle: Build it\n---\n' > "$r/plans/0001-build.md"
  commit_at "$r" 2026-01-04T10:00:00Z -m "Add plan 0001" -m "Derives-From: docs/adr/0001-choice.md"
  git -C "$r" rm -q plans/0001-build.md
  commit_at "$r" 2026-01-06T10:00:00Z -m "Complete plan 0001" -m "Completes: plans/0001-build.md"
  git -C "$r" tag v0.1.0
  printf -- '---\ntitle: Which choice?\n---\nv2\n' > "$r/docs/adr/0001-choice.md"
  commit_at "$r" 2026-01-08T10:00:00Z -m "Revise ADR 0001" -m "Revises: docs/adr/0001-choice.md"
}

# A minimal opted-in project on top of the chain repo, with fake adapters.
make_project() { # dir content_type
  local r=$1 ct=$2
  make_chain_repo "$r"
  mkdir -p "$r/site/content/changes" "$r/site/content/summaries" "$r/site/content/docs" \
    "$r/site/content/guides"
  cat > "$r/site/project.yaml" <<YAML
name: "Fixture project"   # a comment
repository: example/fixture
content_type: $ct
languages: [fake]
upcoming:
  source: fake
YAML
  printf -- '---\ntitle: Overview\n---\nOVERVIEW-TEXT See #42.\n' > "$r/site/content/overview.md"
  printf -- '---\ntitle: Guide\n---\nGUIDE-TEXT See #42.\n' > "$r/site/content/docs/guide.md"
  printf -- '---\ntitle: Start here\n---\nHOWTO-TEXT See #42.\n' > "$r/site/content/guides/start.md"
  printf -- '---\ntitle: ENTRY-ONE\ndate: 2026-01-05\ntheme: Core\nrefs: ["#42", "docs/adr/0001-choice.md", "plans/0001-build.md"]\n---\nBody.\n' \
    > "$r/site/content/changes/2026-01-05-entry-one.md"
  printf -- '---\ntitle: Week of 2026-01-01\nperiod_start: 2025-12-25\nperiod_end: 2026-01-06\n---\nSUMMARY-TEXT See #42.\n' \
    > "$r/site/content/summaries/2026-W01.md"
  commit_at "$r" 2026-01-09T10:00:00Z -m "Opt in"
  mkdir -p "$TMP/adapters/upcoming" "$TMP/adapters/reference"
  # Fakes as the registry delivers them: with an extension, no executable bit.
  printf 'echo %s\n' "'[{\"title\":\"UPCOMING-ITEM\",\"ref\":\"#7\",\"state\":\"open\",\"theme\":\"Core\"}]'" \
    > "$TMP/adapters/upcoming/fake.sh"
  printf 'import json\nprint(json.dumps([{"path": "pkg/mod.md", "title": "pkg.mod", "content": "REFERENCE-TEXT"}]))\n' \
    > "$TMP/adapters/reference/fake.py"
  chmod -x "$TMP/adapters/upcoming/fake.sh" "$TMP/adapters/reference/fake.py"
  export SITE_ADAPTERS="$TMP/adapters" SITE_OFFLINE=1
}

build() { bash "$TILE/core/build.sh" "$@"; }
