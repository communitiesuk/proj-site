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

usage() { echo "usage: require-site-check.sh [--trunk <branch>] [--repo <owner/name>]" >&2; exit 2; }
trunk=; repo=
while [ $# -gt 0 ]; do
  case $1 in
    --trunk) [ $# -ge 2 ] || usage; trunk=$2; shift 2 ;;
    --repo) [ $# -ge 2 ] || usage; repo=$2; shift 2 ;;
    *) usage ;;
  esac
done

if [ -z "$trunk" ]; then
  git rev-parse --git-dir >/dev/null 2>&1 ||
    { echo "require-site-check.sh: not in a git repository; pass --trunk" >&2; exit 2; }
  trunk=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||') || trunk=
  if [ -z "$trunk" ]; then
    for b in dev main master; do
      if git rev-parse -q --verify "refs/heads/$b" >/dev/null || git rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null; then trunk=$b; break; fi
    done
  fi
  [ -n "$trunk" ] || trunk=$(git symbolic-ref -q --short HEAD 2>/dev/null) || trunk=
  [ -n "$trunk" ] || { echo "require-site-check.sh: cannot resolve the trunk; pass --trunk" >&2; exit 2; }
fi
if [ -z "$repo" ]; then
  repo=$(git remote get-url origin 2>/dev/null | sed -E 's#^(https://[^/]+/|git@[^:]+:)##; s#\.git$##') || repo=
  [ -n "$repo" ] || { echo "require-site-check.sh: no origin remote; pass --repo" >&2; exit 2; }
fi

prot="repos/$repo/branches/$trunk/protection"
contexts="$prot/required_status_checks/contexts"
by_hand="Set it by hand: https://github.com/$repo/settings/branches"
P='{"required_status_checks":{"strict":false,"checks":[{"context":"check"}]},"enforce_admins":null,"required_pull_request_reviews":null,"restrictions":null}'
C='{"contexts":["check"]}'
err=$(mktemp); trap 'rm -f "$err"' EXIT

# write <method> <path> <json>: make the call; on failure print gh's error to
# stderr and the call itself to stdout, and exit 1.
write() {
  if printf '%s' "$3" | gh api -X "$1" "$2" --input - >/dev/null 2>"$err"; then return 0; fi
  cat "$err" >&2
  echo "echo '$3' | gh api -X $1 $2 --input -"
  exit 1
}

if current=$(gh api "$prot" 2>"$err"); then
  if ! printf '%s' "$current" | jq -e '.required_status_checks != null' >/dev/null; then
    echo "$by_hand"; exit 3
  fi
  if printf '%s' "$current" | jq -e '[.required_status_checks.contexts[]?, .required_status_checks.checks[]?.context] | index("check") != null' >/dev/null; then
    echo "The site check is already required on $trunk; nothing changed."; exit 0
  fi
  write POST "$contexts" "$C"
  echo "Added the site check to the required checks on $trunk."
elif printf '%s' "$current" | jq -e '.message == "Branch not protected"' >/dev/null 2>&1; then
  write PUT "$prot" "$P"
  echo "Required the site check on $trunk."
else
  cat "$err" >&2
  echo "$by_hand"
  exit 1
fi
