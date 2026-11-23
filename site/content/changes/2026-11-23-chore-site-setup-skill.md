---
title: Opting in and building the site is now a skill, ready to publish
date: 2026-11-23
theme: Packaging
refs: ["plans/0001-project-site.md"]
---
Checking the package before publishing showed that the registry would have
shipped only the two writing skills, without the site build, adapters or
scripts. These now live inside a new `site-setup` skill, which also guides an
agent through opting a project in and building or previewing its site. The
package now carries everything a project needs.
