---
title: How the site is written and built
weight: 2
---
## What a project holds

```
site/
  project.yaml                         name, repository, content type, languages, upcoming-work source
  content/overview.md                  hand-written
  content/guides/                      hand-written guides
  content/docs/                        hand-written technical docs
  content/changes/<date>-<branch>.md   one entry per pull request
  content/summaries/<ISO week>.md      one weeknote per week
```

The site's tabs, in order, are Overview, Guides (`/guides/`), Docs
(`/docs/`), Weeknotes (`/weeknotes/`), Latest updates (`/updates/`) and
Coming next (`/coming-next/`). The committed folders keep their names:
`changes/` becomes Latest updates and `summaries/` becomes Weeknotes. The
content type decides two tabs: `knowledge` and `both` have Guides; `code`
and `both` have Docs with reference generated from docstrings under
`/docs/reference/`, and a `knowledge` project has Docs when
`site/content/docs/` holds a page. Every site has the other four.

## Who writes what

- **People** write the overview and the guides.
- **The `site-update` skill** keeps those pages, and the code's docstrings, in
  line with the code before each pull request.
- **The `site-writing` skill** writes the per-PR entry before each pull
  request, and the weekly summary when one is due.
- **The build** reads the timeline of explored, decided, built and shipped work
  from the git history, lists upcoming work from GitHub issues, generates
  reference docs from docstrings, and links every `#N`, `docs/` or `plans/`
  path and commit ID on the site to GitHub.

## Coming next

Each row is an open issue's title, linked to the issue, and its theme: the
issue's first label named `theme:<name>`. Rows are grouped by theme and
ordered by the date the issue was opened, oldest first; readers can ungroup
them, reverse the order, and choose which themes to show. A row expands only
where the issue's author wrote a section headed `## Site summary` in its
body, and then shows that section's text alone.

## The weeknote

A weeknote is due when there is none for the ISO week containing the most
recent Thursday (UTC). No week is skipped: if nobody raises a pull request
from Thursday to Sunday, the next pull request, even the following week,
writes it. Each weeknote covers the time since the previous one.

## What is checked

Every pull request must add a per-PR entry, and must include the weeknote if
one is due and no other open pull request already carries it. Everything
under `site/` is public: no named people, internal events only where they
publicised the project, and no secrets.
