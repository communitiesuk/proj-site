---
title: How should an opted-in project's site be organised and presented?
date: 2026-11-25
---

# How should an opted-in project's site be organised and presented?

> **Directive for the implementer**: when implementing this ADR, invoke the `plans` skill to produce the corresponding plan artifact. Do not begin implementation without a plan.

## Context

ADR 0001 decides what the site contains but not how it is laid out or looked at. The human reviewed the site and asked for clearer separation between section headings, the MHCLG colour scheme, no "Latest summary" on the overview (a visitor may not know what summaries are), clearer tab names, long-form docs split from technical documentation, and a new link order.

A mockup built from real site content, over several rounds of feedback, settled the design below.

## Decision

**Tabs.** In this order: Overview, Guides, Docs, Weeknotes, Latest updates, Coming next. Weeknotes, Latest updates and Coming next replace Summaries, Changes and Upcoming; Guides and Docs split the old "Docs" where needed.
- Guides holds hand-written long-form docs, such as how to opt a project in.
- Docs holds technical documentation: hand-written technical pages and the reference pages generated from docstrings.

**Web addresses** match the tabs: `/guides/`, `/docs/`, `/weeknotes/`, `/updates/`, `/coming-next/`. Old `/summaries/`, `/changes/` and `/upcoming/` links break; the site is days old.

**Overview.** No "Latest summary". It shows a card per section with a one-line description, then "What happened this week": the latest weeknote with a short extract and a line saying what weeknotes are.

**Colours** follow the MHCLG 2025 template:
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

**Coming next.** Each row is the item's title, link and a tag with its theme. The upcoming-work source supplies an optional site summary per item; a row expands in place only where one exists. The GitHub-issues adapter takes it from a section written for the site. An issue's opening text is never shown.

The table lets users group by theme, order by date, and include or exclude themes. Filtering is by theme only for now; other criteria may come later. The controls combine: filter, then group, with date order inside each group.

## Alternatives considered

- **"Longform docs" and "Tech docs" as labels.** Replaced by Guides and Docs. "How-to guides" is long for a tab, "Using [project]" changes the label per project, "Handbook" sounds odd for a code project.
- **A grey band behind the title only.** Replaced by a whole-page grey background.
- **A switch labelled with the current mode** is redundant. Following only the system setting, or always light, ignores that people work in different lighting.
- **Coming next showing an issue's opening** (unreviewed; some open with internal notes), or separate description pages (they would send readers to a sentence or two).
- **Coming next rows as title and link only, with no other text from the item.** Adopted first; reversed because the theme tag tells readers what an item belongs to and is the basis for grouping and filtering.
- **Keeping the old web addresses.** The address bar should match the tab.

## Consequences

- Every opted-in project gets the new presentation.
- Issue authors can opt text into the public site.
- Left to the plan: the content folders; when Guides and Docs appear, within ADR 0001's content-type rule; the opt-in marker in an issue; which date orders the table; the default view; how the controls look; the link from an expanded row to the full GitHub discussion; the "Open all" control; section intro lines; the overview title treatment.
- Out of scope: filter criteria other than theme; per-project theming (#22); a guard against sensitive text (#24); which issues count as coming next (#21).
- The colours come from the template, not the intranet palette page, which could not be fetched; they may need revisiting if that page differs.

## References

- ADR 0001: its site contents, sections by content type, and weeknotes-style summary are what this ADR lays out and renames; its upcoming-work adapter supplies Coming next.
- ADR 0002: the layouts ship in the public tile, so they are public.
