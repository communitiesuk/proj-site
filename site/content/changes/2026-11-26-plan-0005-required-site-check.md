---
title: Planned the opt-in offer to make the site check required
date: 2026-11-26
theme: Release assurance
refs: ["docs/adr/0001-project-site.md", "plans/0005-required-site-check.md"]
---
The team planned how opting in will offer to make the site check required
before merging. A small script adds the check to the trunk's protection
without changing any other setting, and says plainly what to do by hand
when it cannot. The opt-in asks first and lists the step for later if the
maintainer declines or lacks admin rights. The guides explain the step, and
the plan ends with version 0.5.0 and a check in a throwaway repository that
a pull request cannot merge while the site check fails.
