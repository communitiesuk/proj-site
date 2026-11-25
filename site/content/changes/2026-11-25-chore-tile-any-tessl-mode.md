---
title: Any project can opt in, however it installs its tessl tools
date: 2026-11-25
theme: Packaging
refs: ["docs/adr/0002-tile-distribution.md", "plans/0002-tile-distribution.md"]
---
Following the decision to stop requiring one way of installing tessl tools, the
team planned and built the change. The site's two workflows now install the
proj-site tools themselves on each run, and stop with a clear message if the
tools did not arrive, so a project no longer has to commit them. Opting in no
longer warns about how a project installs its tools, and the guides say any
way works. The tools are now marked public, so the workflows need no login;
version 0.2.0 carries the change once it is published.
