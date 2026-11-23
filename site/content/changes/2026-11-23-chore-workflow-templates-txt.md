---
title: Projects installing from the registry get the workflows too
date: 2026-11-23
theme: Packaging
refs: ["plans/0001-project-site.md"]
---
After the first release was published, installing it from the registry showed
that the two workflow templates had not arrived, so opting a project in
stopped part-way. The templates now ship in a form the registry delivers, the
opt-in script restores their names, and a test keeps that format in place.
Version 0.1.1 carries the fix.
