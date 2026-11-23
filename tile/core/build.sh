#!/usr/bin/env bash
# build.sh <project-dir> <out-dir> [--no-render]
#
# Build an opted-in project's site.
#
# Reads <project-dir>/site/project.yaml and assembles a Hugo source tree in
# <out-dir>/src (never committed), then renders it into <out-dir>/public with
# Hugo unless --no-render is given.
#
# The source tree:
#   src/hugo.toml               generated: title from `name`, baseURL from
#                               $SITE_BASE_URL (default "/"), menu of enabled sections
#   src/layouts/                copied from tile/core/layouts
#   src/content/_index.md       from site/content/overview.md (title "Overview")
#   src/content/changes/        site/content/changes/*.md, each with `week`
#                               (%G-W%V of its date) and, unless $SITE_OFFLINE=1,
#                               `pr` (number of the PR that added it, via gh) added
#   src/content/summaries/      site/content/summaries/*.md
#   src/content/upcoming/       section page; items in src/data/upcoming.json
#   src/content/docs/           site/content/docs/** — only for knowledge|both
#   src/content/reference/      pages from each `languages` adapter — only for code|both
#   src/data/timeline.json      from timeline.sh, `recent` since the latest summary's
#                               `period_end` (all recent when there is no summary)
#   src/data/upcoming.json      from the `upcoming.source` adapter
#
# Every section dir gets an _index.md if none was supplied. Environment:
#   SITE_GH       gh command (default gh); SITE_OFFLINE=1 skips PR lookups
#   SITE_ADAPTERS adapters root (default tile/adapters next to this script)
#   HUGO          hugo command (default hugo)
#
# Exits 2 on a usage error or a missing/invalid project.yaml (content_type
# not knowledge|code|both); exits non-zero if an adapter or Hugo fails, with
# the failing step named on stderr.
:
