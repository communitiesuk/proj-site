---
title: Opting in will offer to make the site check required before merging
date: 2026-11-26
theme: Release assurance
refs: ["docs/adr/0001-project-site.md", "#20"]
---
The site check reports a missing per-PR entry or weeknote, but nothing has
stopped such a pull request from merging. The team decided that opting a
project in will offer, with the maintainer's agreement and admin rights, to
make the site check a required status on the trunk, and the guides will
explain the step. Only the site check is required, and branches need not be
brought up to date with the trunk first. Projects using myelin's landing
command will need it to wait for checks before merging, which is being
taken up in myelin.
