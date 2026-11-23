---
title: How the site is written and built
weight: 2
---
## What a project holds

```
site/
  project.yaml                         name, repository, content type, languages, upcoming-work source
  content/overview.md                  hand-written
  content/docs/                        hand-written guides
  content/changes/<date>-<branch>.md   one entry per pull request
  content/summaries/<ISO week>.md      one summary per week
```

The content type decides the sections: `knowledge` adds the guides, `code`
adds generated reference docs, and `both` adds both. Every site has the
overview, changes, summaries and upcoming work.

## Who writes what

- **People** write the overview and the guides.
- **The `site-update` skill** keeps those pages, and the code's docstrings, in
  line with the code before each pull request.
- **The `site-writing` skill** writes the per-PR entry before each pull
  request, and the weekly summary when one is due.
- **The build** reads the timeline of explored, decided, built and shipped work
  from the git history, lists upcoming work from GitHub issues, and generates
  reference docs from docstrings.

## The weekly summary

A summary is due when there is none for the ISO week containing the most
recent Thursday (UTC). No week is skipped: if nobody raises a pull request
from Thursday to Sunday, the next pull request, even the following week,
writes it. Each summary covers the time since the previous one.

## What is checked

Every pull request must add a per-PR entry, and must include the summary if
one is due and no other open pull request already carries it. Everything
under `site/` is public: no named people, internal events only where they
publicised the project, and no secrets.
