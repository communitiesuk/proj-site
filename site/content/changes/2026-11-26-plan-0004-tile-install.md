---
title: Planned how the site workflows will install only the site tools
date: 2026-11-26
theme: Packaging
refs: ["docs/adr/0002-tile-distribution.md", "plans/0004-tile-install.md", "plans/0002-tile-distribution.md"]
---
The team planned the change to the site's workflows: each will read the
version of the proj-site tools the project pins, install only those in a
temporary folder, and stop with a clear message if they are missing or
unpinned. Projects already opted in will regenerate their two workflows.
The plan ends with version 0.4.0 and a check that it installs without
signing in. It replaces the rest of the earlier distribution plan, which
is closed.
