---
title: Overview
---
**proj-site** gives a myelin project a public website that keeps itself up to
date. A project opts in once; from then on its site shows:

- **For people who use what the project produces:** a hand-written overview,
  long-form guides, and reference documentation generated from the code's
  docstrings.
- **For stakeholders:** a timeline of what was explored, decided, built and
  shipped, read straight from the project's history; a short entry for every
  pull request; a weekly summary; and what is coming up next.

The content is written as part of normal work. An agent skill writes the
per-PR entry, and the weekly summary when one is due, before a pull request is
raised, so it is reviewed with the change. A check on every pull request makes
sure neither is forgotten, and each merge redeploys the site to GitHub Pages.

This site is itself built by proj-site.
