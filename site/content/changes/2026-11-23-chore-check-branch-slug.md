---
title: The pull-request check suggests the right entry name
date: 2026-11-23
theme: Pilot
refs: ["plans/0001-project-site.md"]
---
When a pull request is missing its entry, the check names the file to add.
On GitHub it suggested a name based on the merge commit rather than the
pull request's branch. It now uses the branch name, so the suggested file is
the one the writing skill would create.
