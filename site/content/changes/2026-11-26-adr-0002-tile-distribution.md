---
title: Site workflows will install only the site tools, not a project's other dependencies
date: 2026-11-26
theme: Packaging
refs: ["docs/adr/0002-tile-distribution.md"]
---
The site's workflows installed every tool a project depends on just to get
the proj-site tools, which is slow and runs code the workflows do not need.
The team decided that the workflows will install the proj-site tools on
their own, at the version the project already pins, and stop with a clear
message if the project does not list them.
