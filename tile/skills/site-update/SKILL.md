---
name: site-update
description: Keeps a proj-site project's hand-written user documentation — site/content/overview.md, the guides under site/content/guides/, the technical docs under site/content/docs/, and code docstrings — aligned with what the project actually contains, editing passages that describe removed, renamed or changed behaviour. TRIGGER before raising a pull request that changes code or docs in a repository with site/project.yaml, or when asked to bring the site's docs up to date. SKIP for the per-PR entry and weekly summary (use the `site-writing` skill), for generated reference docs (built from docstrings at deploy time), and for repositories without site/project.yaml.
---

# Site update

The site's user-facing pages are hand-written, so they drift when the code changes. Before a pull request is raised, make every hand-written passage true of the branch as it stands. The edits are committed on the branch and reviewed with the change.

What you edit:

| File | Edit when |
| --- | --- |
| `site/content/overview.md` | it names a feature, command or output that the branch adds, removes, renames or changes |
| `site/content/guides/**` | a passage describes behaviour the branch changed |
| `site/content/docs/**` | a passage describes behaviour the branch changed (not the generated reference) |
| Docstrings in the code | a docstring no longer matches its function (reference docs are generated from them) |

What you never edit: generated reference docs (they are built at deploy time), `site/content/changes/` and `site/content/summaries/` (the `site-writing` skill's), and behaviour in the code.

## Steps

1. **Find what changed.** `git diff <trunk>...HEAD` and `git log <trunk>..HEAD`. List every public name the branch adds, removes or renames (functions, classes, commands, options, files, outputs), and every behaviour it changes.
2. **Find stale passages.** For each item, search the hand-written docs and docstrings for it: `grep -rn "<name>" site/content/overview.md site/content/guides/ site/content/docs/ <source dirs>`. Also read each guide and doc page whose topic the branch touches; a passage can be stale without naming the symbol.
3. **Edit, passage by passage.**
   - **Removed**: delete the passage, or replace it with one sentence saying the feature was removed and what to use instead, if the commits say. Delete a section heading whose content goes with it; keep the rest of the page.
   - **Renamed**: change every mention to the new name.
   - **Changed**: rewrite the passage to describe the new behaviour, with a corrected example.
   - **Added**: add a short passage where a reader would look for it, if the feature is user-facing.
   Keep the page's voice. Change only what the branch made untrue; do not rewrite pages for style.
4. **Check.** Re-run the searches from step 2: no passage still describes the old behaviour, and every page still covers what it covered before, apart from what was removed. Never delete a whole page because one section went stale.
5. **Commit** the edits on the branch, with a message naming the passages changed.

## Public content rules

Everything under `site/` is published: no named people, internal events only where they publicised the project, and no secrets.

## Do not

- Do not leave a passage that tells readers to use something the branch removed.
- Do not delete a whole doc page or the overview to remove one stale section.
- Do not change code behaviour to match the docs; the code is the source of truth here.
- Do not edit generated reference pages, entries or summaries.

## When you may deviate

- **The branch changes nothing user-facing** (tests, CI, internal refactors with no renamed public names): check, find nothing stale, and commit nothing.
- **Asked to bring the docs up to date with no branch in play**: compare the docs with the code on the trunk instead of a diff.
