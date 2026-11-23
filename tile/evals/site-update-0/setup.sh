#!/usr/bin/env bash
#
# Fixture for evals/site-update-0.
#
# A repository opted into proj-site (content_type both). On dev, the code
# offers search() and export_csv(), and site/content/docs/exporting.md and
# site/content/overview.md describe both. Branch remove-csv-export, checked
# out, removes export_csv() from the code and its tests. The task asks only
# that the branch be prepared for review; the site-update skill must find and
# change the hand-written passages that still describe CSV export.
#
#   - export_csv named in the overview and in a long-form doc: lets the
#     "no stale passage remains" criterion fail on either file.
#   - search() documented alongside it: lets the "unrelated passages kept"
#     criterion fail when an agent deletes whole files.
#   - Tags fixture-base-dev and fixture-base-branch: let "committed on the
#     branch after the fixture" be scored.
#   - No remote.
set -eu
git init -q .
git symbolic-ref HEAD refs/heads/dev
git config --local user.name "Lantern Maintainers"
git config --local user.email "maintainers@example.invalid"
git config --local commit.gpgsign false
mkdir -p site/content/docs site/content/changes src tests
cat > site/project.yaml <<YAML
name: Lantern
repository: example/lantern
content_type: both
languages: [python]
upcoming:
  source: github-issues
YAML
cat > site/content/overview.md <<'MD'
---
title: Overview
---
Lantern makes council meeting minutes searchable. Use `search()` to find
decisions by keyword, and `export_csv()` to download the results as a CSV file.
MD
cat > site/content/docs/exporting.md <<'MD'
---
title: Searching and exporting
---
## Searching

Call `search("parking")` to get every decision mentioning parking.

## Exporting to CSV

Call `export_csv(results, "out.csv")` to write search results to a CSV file
with one row per decision.
MD
cat > src/lantern.py <<'PY'
def search(q):
    """Return decisions matching q."""
    return []


def export_csv(results, path):
    """Write results to a CSV file at path."""
    with open(path, "w") as f:
        f.write("decision\n")
PY
printf 'from lantern import search, export_csv\n\ndef test_search():\n    assert search("x") == []\n' > tests/test_lantern.py
git add -A && git commit -q -m "Lantern with search and CSV export"
git tag fixture-base-dev
git checkout -q -b remove-csv-export
cat > src/lantern.py <<'PY'
def search(q):
    """Return decisions matching q."""
    return []
PY
printf 'from lantern import search\n\ndef test_search():\n    assert search("x") == []\n' > tests/test_lantern.py
git add -A && git commit -q -m "Remove CSV export" -m "Nobody used it; JSON via the API replaces it."
git tag fixture-base-branch
