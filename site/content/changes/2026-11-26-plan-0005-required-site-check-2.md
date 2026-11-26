---
title: Version 0.5.0 is published, and a required site check is proven to block merges
date: 2026-11-26
theme: Release
refs: ["plans/0005-required-site-check.md"]
---
Version 0.5.0 of the site tools is published. On real test repositories
the team confirmed that opting in asks before making the site check
required, that the check is then added without changing other protection
settings, and that a pull request without its entry cannot merge until the
check passes. That completes the plan for this change.
