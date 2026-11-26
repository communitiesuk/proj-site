#!/usr/bin/env bash
# require-site-check.sh [--trunk <branch>] [--repo <owner/name>]
#
# Make the site check (the `check` job of site-check.yml) a required status on
# the trunk, through GitHub branch protection. Run it, with the user's
# confirmation and admin rights on the repository, as
# `bash .tessl/plugins/mhclg-aaai/proj-site/skills/site-setup/scripts/require-site-check.sh`.
#
# Trunk: --trunk, else as site-init.sh resolves it (origin/HEAD's target, else
# the first existing of dev, main, master, else the current branch).
# Repository: --repo, else owner/name from the origin remote. Uses git, gh, jq.
#
# Reads repos/<repo>/branches/<trunk>/protection, then:
#   unprotected ("Branch not protected")  PUT protection requiring `check`, not
#       strict, nothing else set (GitHub then also blocks force pushes to and
#       deletion of the trunk); prints "Required the site check on <trunk>."
#   required status checks without check  POST {"contexts":["check"]} to their
#       contexts, keeping the others and `strict`; prints "Added the site check
#       to the required checks on <trunk>."
#   check already required               changes nothing; prints "The site check
#       is already required on <trunk>; nothing changed."
#   protected, no required status checks  changes nothing; prints only
#       "Set it by hand: https://github.com/<repo>/settings/branches"; exit 3.
# On existing protection it changes only the required status checks; it never
# prints or makes a call that would replace existing protection.
#
# Exits 0 on success; 1 when a write fails (prints, on stdout, the exact
# `gh api` call it would have made) or the first read fails (no login, no
# rights, no network: prints the "Set it by hand:" line), with gh's error on
# stderr; 2 on a usage error or when the trunk or repository cannot be
# resolved; 3 as above.
set -eu
echo "require-site-check.sh: not implemented" >&2
exit 1
