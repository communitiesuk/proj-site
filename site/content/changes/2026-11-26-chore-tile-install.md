---
title: Site workflows now install only the site tools
date: 2026-11-26
theme: Packaging
refs: ["docs/adr/0002-tile-distribution.md", "plans/0004-tile-install.md"]
---
The site's two workflows no longer install every tool a project depends on.
Each now reads the version of the proj-site tools the project pins, installs
only those into a temporary folder, or uses a local copy when the project
points at one, and stops with a clear message if the tools are missing,
unpinned or did not arrive. Projects already opted in update by deleting
their two workflows and running the opt-in script again. Version 0.4.0
carries the change once published.
