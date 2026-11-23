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
exit 0
