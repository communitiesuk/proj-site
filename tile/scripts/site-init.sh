#!/usr/bin/env bash
# site-init.sh [--content-type knowledge|code|both] [--trunk <branch>] [--with-claude-hook]
#
# Opt the project in the current directory (a git repository's root) into
# proj-site. Run it as `bash .tessl/plugins/mhclg-aaai/proj-site/scripts/site-init.sh`
# after `tessl install mhclg-aaai/proj-site`.
#
# Creates, only where absent (an existing file is never changed):
#   site/project.yaml               name (the repository directory's name),
#                                   repository (owner/name from the origin
#                                   remote, else empty), content_type (the flag,
#                                   else `both` when the project has *.py outside
#                                   site/ and .tessl/, else `knowledge`),
#                                   languages ([python] when it has *.py, else []),
#                                   upcoming.source github-issues
#   site/content/overview.md        a stub overview to edit
#   .github/workflows/site-check.yml   from the tile's templates
#   .github/workflows/site-pages.yml   with __TRUNK__ replaced by the trunk
# With --with-claude-hook, merges the tile's claude-hook.json into
# .claude/settings.json (created if absent), adding the hook only if that
# command is not already registered.
#
# Trunk: --trunk, else origin/HEAD's target, else the first existing of dev,
# main, master. A second run makes no changes. Prints what it created and the
# next steps (enable Pages; raise the opt-in PR with its own entry). Warns when
# tessl.json is not in vendored mode, since the workflows run the vendored tile.
# Exits 2 on a usage error or when not at a git repository's root; no existing
# weeknotes are migrated.
:
