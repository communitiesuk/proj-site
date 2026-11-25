---
title: How should an opted-in project's site be organised and presented?
date: 2026-11-25
---

# How should an opted-in project's site be organised and presented?

> **Directive for the implementer**: when implementing this ADR, invoke the `plans` skill to produce the corresponding plan artifact. Do not begin implementation without a plan.

## Context

ADR 0001 decides what the site contains but not how it is laid out or looked at. The human reviewed the site and asked for: clearer separation between section headings; the MHCLG colour scheme; no "Latest summary" on the overview, because a visitor may not know what summaries are; clearer tab names; a split of long-form docs from technical documentation; and a new link order.

A mockup built from real site content, over several rounds of feedback, settled the design below. The shared layouts and menu code change, so every opted-in project gets the result.

## Decision

**Tabs.** In this order: Overview, Guides, Docs, Weeknotes, Latest updates, Coming next. They replace "Summaries", "Changes" and "Upcoming" (the first three renames) and split the old "Docs".
- Guides holds hand-written long-form docs, such as how to opt a project in.
- Docs holds technical documentation: hand-written technical pages and the reference pages generated from docstrings.
- Guides and Docs appear only when they have at least one page; the other four always appear.

**Web addresses** match the tabs: `/guides/`, `/docs/`, `/weeknotes/`, `/updates/`, `/coming-next/`. Old `/summaries/`, `/changes/` and `/upcoming/` links break; there are no redirects.

**Overview.** No "Latest summary". It shows a card per section with a one-line description, then "What happened this week": the latest weeknote with a short extract and a line saying what weeknotes are.

**Colours** follow the MHCLG 2025 template, as kept by the chart skill:
- teal `#00625E`; magenta `#932A71` as the accent; surface grey `#E5E5E5`;
- secondary colours only for the Timeline stage labels;
- teal links, not the template's `#0099CC`, which is too pale on white.

**Separation.**
- A teal header bar, and a white tab strip with the current tab underlined in teal.
- Section headings carry a thick teal line above them and more space around them.
- "By week" and "Timeline" on Latest updates are two in-page tabs.
- Page background `#f3f3f3`; cards, code blocks, tab strip, footer and panels white; dividing lines `#d4d4d4`.
- The project title is large, with a 4px teal line under it and no band.

**Light and dark.** A switch in the header bar. It follows the system setting on a first visit, then remembers the person's choice in that browser. It is labelled with what it does: a moon and "Dark mode" in light mode, a sun and "Light mode" in dark mode; screen readers read only that label. Dark-mode text is softer than white: body `#d6dada`, secondary `#a2a9ab`.

**GitHub links.** Anything from GitHub links to its page: PRs and issues with `#N` as the link text, document paths to the file, short commit IDs to the commit. Each update's page has an "On GitHub" section linking its PR and the documents it refers to.

**Coming next.** Each row is the issue title plus its `#N` link. A row expands in place only where the issue has a short section written for the site; its text is shown, with a link to the full discussion on GitHub. Without that section the row does not expand. The issue's opening text is never shown.

## Alternatives considered

- **"Longform docs" and "Tech docs" as labels.** Replaced by Guides and Docs. "How-to guides" is long for a tab, "Using [project]" changes the label per project, "Handbook" sounds odd for a code project.
- **A grey band behind the title only.** Replaced by a whole-page grey background.
- **A switch labelled with the current mode,** or following only the system setting, or always light. The switch labelled with its action was chosen.
- **Coming next as title and link only,** or showing the opening of the issue (unreviewed, and some issues open with internal notes), or separate short description pages (a sentence or two each). The opt-in summary was chosen.
- **Keeping the old web addresses.** Not chosen: the address bar should match the tab, and the site is days old.

## Consequences

- Every opted-in project gets the new layout, and tests of the old layout need updating.
- Guides and Docs are conditional, so a project with no hand-written docs shows neither tab unless its content type generates reference pages.
- Issue authors can opt text into the public site; collecting that text means a small change to how the site reads issues from GitHub.
- Left to the plan: the content folders and how the writing and PR-check skills keep working with them; the exact opt-in marker in an issue; the section intro lines, "Open all" control and overview title treatment.
- Out of scope: per-project theming (#22); a guard against sensitive text (#24); unreviewed issue text reaching the public site (#23); which issues count as coming next (#21). The colours were taken from the template, not the intranet palette page, which could not be fetched; they change if that page differs.

## References

- ADR 0001: its site contents, sections by content type, and weeknotes-style summary are what this ADR lays out and renames; its Hugo-based core and adapters hold the layouts changed.
- ADR 0002: the layouts ship in the public tile, so they are public.
