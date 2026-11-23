#!/usr/bin/env bash
# hook-pr-create.sh - optional Claude Code PreToolUse hook (matcher: Bash).
#
# Reads the hook JSON on stdin (.tool_name, .tool_input.command, .cwd).
# If the tool is Bash and the command contains `gh pr create`, checks that the
# current branch ADDS (diff-filter A, against the merge-base with the trunk)
# at least one file under site/content/changes/.
#
# Trunk: env SITE_TRUNK if set, else the target of origin/HEAD, else the first
# existing of dev, main, master (local, then origin/).
#
# Exit 2, with a message on stderr, when no entry is added: the message tells
# the agent to run the `site-writing` skill to write
# site/content/changes/<YYYY-MM-DD>-<branch-slug>.md before raising the PR
# (Claude Code blocks the tool call on exit 2 and feeds stderr back).
# Exit 0, silently, in every other case: another tool or command, not a git
# repo, no site/project.yaml at the repo root, no trunk found, malformed JSON,
# or any error of the hook's own. It never fails closed.
#
# Requires: bash, git, jq. CI (check-pr.sh) remains the enforcement.
input=$(cat) || exit 0
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
[ "$tool" = Bash ] || exit 0
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
case "$cmd" in *"gh pr create"*) ;; *) exit 0;; esac
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
[ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
cd "$cwd" 2>/dev/null || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "$root/site/project.yaml" ] || exit 0
cd "$root" || exit 0

trunk=${SITE_TRUNK:-}
if [ -z "$trunk" ]; then
  trunk=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null) || trunk=
fi
if [ -z "$trunk" ]; then
  for b in dev main master; do
    for ref in "$b" "origin/$b"; do
      if git rev-parse -q --verify "refs/heads/$ref" >/dev/null 2>&1 ||
         git rev-parse -q --verify "refs/remotes/$ref" >/dev/null 2>&1; then
        trunk=$ref; break 2
      fi
    done
  done
fi
[ -n "$trunk" ] || exit 0

base=$(git merge-base "$trunk" HEAD 2>/dev/null) || exit 0
added=$(git diff --name-only --diff-filter=A "$base" HEAD -- site/content/changes/ 2>/dev/null) || exit 0
[ -z "$added" ] || exit 0

branch=$(git symbolic-ref -q --short HEAD 2>/dev/null) || branch=branch
slug=$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//')
today=$(date -u +%Y-%m-%d)
cat >&2 <<MSG
This branch adds no change entry under site/content/changes/. Before raising
the PR, run the \`site-writing\` skill to write
site/content/changes/${today}-${slug}.md, commit it, then run gh pr create again.
MSG
exit 2
