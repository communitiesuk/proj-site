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
#   `site-writing` skill.
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
echo "check-pr.sh: not implemented" >&2
exit 70
