---
title: proj-site now publishes its own project site
date: 2026-11-23
theme: Pilot
refs: ["docs/adr/0001-project-site.md", "plans/0001-project-site.md"]
---
This project is the first to opt in to the tooling it builds. It installs its
own tile, runs the opt-in script, and gains a site with an overview and two
guides: how to opt a project in, and how the site is written and built. The
pull-request check now runs on this repository, and every merge deploys the
site to GitHub Pages.
