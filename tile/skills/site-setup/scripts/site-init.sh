#!/usr/bin/env bash
# site-init.sh [--content-type knowledge|code|both] [--trunk <branch>] [--with-claude-hook]
#
# Opt the project in the current directory (a git repository's root) into
# proj-site. Run it as `bash .tessl/plugins/mhclg-aaai/proj-site/skills/site-setup/scripts/site-init.sh`
# after `tessl install mhclg-aaai/proj-site`.
#
# Creates, only where absent (an existing file is never changed):
#   site/project.yaml               name (the repository name from the origin
#                                   remote, else the directory's name),
#                                   repository (owner/name from the origin
#                                   remote, else empty), content_type (the flag,
#                                   else `both` when the project has *.py outside
#                                   site/ and .tessl/, else `knowledge`),
#                                   languages ([python] when it has *.py, else []),
#                                   upcoming.source github-issues
#   site/content/overview.md        a stub overview to edit
#   .github/workflows/site-check.yml   from the tile's templates (shipped as *.yml.txt)
#   .github/workflows/site-pages.yml   with __TRUNK__ replaced by the trunk
# With --with-claude-hook, merges the tile's claude-hook.json into
# .claude/settings.json (created if absent), adding the hook only if that
# command is not already registered.
#
# Trunk: --trunk, else origin/HEAD's target, else the first existing of dev,
# main, master, else the current branch (a repository with no commits yet). A second run makes no changes. Prints what it created and the
# next steps (enable Pages; raise the opt-in PR with its own entry). Works in
# any tessl mode: the workflows install the tile themselves.
# Exits 2 on a usage error or when not at a git repository's root; no existing
# weeknotes are migrated.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
tile=$(cd "$here/.." && pwd)

usage() { echo "usage: site-init.sh [--content-type knowledge|code|both] [--trunk <branch>] [--with-claude-hook]" >&2; exit 2; }
ctype=; trunk=; hook=0
while [ $# -gt 0 ]; do
  case $1 in
    --content-type) [ $# -ge 2 ] || usage; ctype=$2; shift 2 ;;
    --trunk) [ $# -ge 2 ] || usage; trunk=$2; shift 2 ;;
    --with-claude-hook) hook=1; shift ;;
    *) usage ;;
  esac
done
case $ctype in ""|knowledge|code|both) ;; *) echo "site-init.sh: --content-type must be knowledge, code or both" >&2; exit 2;; esac

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "site-init.sh: not in a git repository" >&2; exit 2; }
[ "$(cd "$root" && pwd -P)" = "$(pwd -P)" ] || { echo "site-init.sh: run from the repository root ($root)" >&2; exit 2; }

if [ ! -f tessl.json ] || [ "$(jq -r '.mode // empty' tessl.json 2>/dev/null)" != vendored ]; then
  echo "site-init.sh: warning: tessl.json is not in vendored mode; the workflows run the tile from .tessl/plugins/mhclg-aaai/proj-site, so set \"mode\": \"vendored\" and reinstall" >&2
fi

created=()
# write_new <path>: write stdin to <path> only if it does not exist.
write_new() {
  if [ -e "$1" ]; then cat > /dev/null; return 0; fi
  mkdir -p "$(dirname "$1")"; cat > "$1"; created+=("$1")
}

has_python() {
  git ls-files -co --exclude-standard -- '*.py' | grep -vE '^(site|\.tessl)/' | grep -q .
}

if [ -z "$trunk" ]; then
  trunk=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||') || trunk=
  if [ -z "$trunk" ]; then
    for b in dev main master; do
      if git rev-parse -q --verify "refs/heads/$b" >/dev/null || git rev-parse -q --verify "refs/remotes/origin/$b" >/dev/null; then trunk=$b; break; fi
    done
  fi
  [ -n "$trunk" ] || trunk=$(git symbolic-ref -q --short HEAD 2>/dev/null) || trunk=
  [ -n "$trunk" ] || { echo "site-init.sh: cannot find the trunk; pass --trunk" >&2; exit 2; }
fi

repo=$(git remote get-url origin 2>/dev/null | sed -E 's#^(https://[^/]+/|git@[^:]+:)##; s#\.git$##') || repo=
name=${repo##*/}; [ -n "$name" ] || name=$(basename "$root")
if has_python; then langs="[python]"; [ -n "$ctype" ] || ctype=both
else langs="[]"; [ -n "$ctype" ] || ctype=knowledge; fi

write_new site/project.yaml <<YAML
name: $name
repository: $repo
content_type: $ctype        # knowledge | code | both
languages: $langs
upcoming:
  source: github-issues
YAML

write_new site/content/overview.md <<MD
---
title: Overview
---
What $name is, who it is for, and what it produces. Edit this page.
MD

write_new .github/workflows/site-check.yml < "$tile/templates/workflows/site-check.yml.txt"
write_new .github/workflows/site-pages.yml < <(sed "s/__TRUNK__/$trunk/g" "$tile/templates/workflows/site-pages.yml.txt")

if [ "$hook" = 1 ]; then
  s=.claude/settings.json
  cmd=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$tile/templates/claude-hook.json")
  if ! { [ -f "$s" ] && jq -e --arg c "$cmd" '[.hooks.PreToolUse[]?.hooks[]?.command] | index($c)' "$s" >/dev/null; }; then
    mkdir -p .claude
    existing='{}'; [ -f "$s" ] && existing=$(cat "$s")
    printf '%s' "$existing" | jq --slurpfile t "$tile/templates/claude-hook.json" \
      '.hooks.PreToolUse = ((.hooks.PreToolUse // []) + $t[0].hooks.PreToolUse)' > "$s.tmp"
    mv "$s.tmp" "$s"; created+=("$s (hook)")
  fi
fi

if [ ${#created[@]} -eq 0 ]; then
  echo "Already opted in: nothing to change."
else
  echo "Created:"; printf '  %s\n' "${created[@]}"
fi
echo "Next steps:"
echo "  1. Edit site/content/overview.md, and site/project.yaml if needed."
echo "  2. Enable GitHub Pages for the repository with \"GitHub Actions\" as the source."
echo "  3. Raise the opt-in PR with its own per-PR entry (the site-writing skill writes it)."
