---
title: Opting in now offers to make the site check required before merging
date: 2026-11-26
theme: Release assurance
refs: ["docs/adr/0001-project-site.md", "plans/0005-required-site-check.md", "#20"]
---
Opting a project in now offers, with the maintainer's agreement, to make the
site check a required status on the trunk, so a pull request cannot merge
while it fails. A new script adds only that check and keeps any protection
already set; where it cannot, it says exactly what to do by hand. The opt-in
script lists the step for later, and the guides explain it, including that
administrators can still bypass it. Version 0.5.0 carries the change once
published.
