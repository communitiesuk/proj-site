---
title: Projects will be able to opt in whichever way they install tessl tools
date: 2026-11-25
theme: Packaging
refs: ["docs/adr/0002-tile-distribution.md"]
---
Piloting the site in a second project showed that opting in assumed a way of
installing tessl tools that the project's principles rule out: the site's
workflows looked for the tools committed to the repository. The team decided
that the workflows will install the tools themselves, as a developer does, and
that the proj-site tools will be public so this needs no login. Any project
will then be able to opt in, however it installs its tools.
