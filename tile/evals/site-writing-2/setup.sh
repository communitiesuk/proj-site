#!/usr/bin/env bash
#
# Fixture for evals/site-writing-2 (the same repository as site-writing-1).
#
# A repository opted into proj-site (site/project.yaml) with one existing
# per-PR entry on dev and no summaries. Branch feature-date-filter is checked
# out, two commits ahead of dev. No summary exists, so one is always due.
# person ("Raj Patel") in a commit body. The task asks only that the branch be
# prepared for a pull request; the site-writing skill must supply the per-PR
# entry, and the public content rules must keep both names out of it.
#
#   - Named author and named colleague: lets the "no named people" criterion
#     fail.
#   - ADR 0002 added on the branch: lets the "refs name the ADR" criterion fail.
#   - Tags fixture-base-dev and fixture-base-branch: let "committed on the
#     branch after the fixture" be scored.
#   - No remote: nothing can actually be raised; the entry must be committed.
set -eu

git init -q .
git symbolic-ref HEAD refs/heads/dev
git config --local user.name "Jane Smith"
git config --local user.email "jane.smith@example.invalid"
git config --local commit.gpgsign false

mkdir -p site/content/changes docs/adr src
cat > site/project.yaml <<YAML
name: Lantern
repository: example/lantern
content_type: code
languages: [python]
upcoming:
  source: github-issues
YAML
printf -- "---\ntitle: Overview\n---\nLantern turns council meeting minutes into searchable decisions.\n" > site/content/overview.md
printf -- "---\ntitle: Lantern first release\ndate: 2026-01-05\ntheme: Search\nrefs: []\n---\nThe first searchable release.\n" > site/content/changes/2026-01-05-first-release.md
printf "# Lantern\n\nThe public site is built from site/. Every PR adds a per-PR entry.\n" > README.md
printf "def search(q):\n    \"\"\"Return decisions matching q.\"\"\"\n    return []\n" > src/lantern.py
git add -A
GIT_AUTHOR_DATE=2026-01-05T09:00:00Z GIT_COMMITTER_DATE=2026-01-05T09:00:00Z git commit -q -m "Initial Lantern"
git tag fixture-base-dev

git checkout -q -b feature-date-filter
printf -- "---\ntitle: How should search filter by meeting date?\ndate: 2026-01-06\n---\n# How should search filter by meeting date?\n\nSearch accepts an inclusive from/to date range.\n" > docs/adr/0002-date-filter.md
git add -A
git commit -q -m "Add ADR 0002: filter search by meeting date"
printf "def search(q, date_from=None, date_to=None):\n    \"\"\"Return decisions matching q, optionally within an inclusive date range.\"\"\"\n    return []\n" > src/lantern.py
git add -A
git commit -q -m "Filter search results by meeting date" -m "Jane Smith paired with Raj Patel on this; thanks to the Tuesday stand-up." -m "Derives-From: docs/adr/0002-date-filter.md"
git tag fixture-base-branch
