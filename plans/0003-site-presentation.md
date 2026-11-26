---
title: Present the project site with the new tabs, colours and links
status: draft
adr: 0003
date: 2026-11-26
deferred_reason: null
---

# Present the project site with the new tabs, colours and links

Implements [ADR 0003](../docs/adr/0003-site-presentation.md), which lays out
what [ADR 0001](../docs/adr/0001-project-site.md) decides; follows
[plan 0001](0001-project-site.md) and [plan 0002](0002-tile-distribution.md).

## Steps

Paths under `S/` mean `tile/skills/site-setup/`. Committed source folders
under a project's `site/content/` keep their names (`changes/`, `summaries/`,
`docs/`) except the new `guides/`; the build writes the section folders that
set the web addresses. Steps 1 to 10 land on one implementation branch. The
maintainer publishes from the trunk (step 11), and the rest of step 11 lands
on a final branch. Each commit that changes `tile/` also runs `tessl install`,
refreshing this repository's vendored `.tessl/plugins/mhclg-aaai/proj-site`.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

1. **Sections, tab order and web addresses.** In `S/core/build.sh`, write
   the build tree as `content/guides/` (from `site/content/guides/`),
   `content/docs/` (from `site/content/docs/`, plus `content/docs/reference/`
   from the reference adapters), `content/weeknotes/` (from
   `site/content/summaries/`), `content/updates/` (from
   `site/content/changes/`, with `week` and `pr` as now) and
   `content/coming-next/`. Menu, in order: Overview, Guides, Docs, Weeknotes,
   Latest updates, Coming next, with `menus.main` names set explicitly (the
   current code title-cases the folder name). Section index titles match the
   tab names. Guides is enabled for `knowledge` and `both`. Docs is enabled
   for `code` and `both`, and for `knowledge` when `site/content/docs/`
   holds a page other than `_index.md`; hand-written pages are copied for
   `knowledge` and `both`, not `code`. `check-pr.sh`, the skills and `timeline.sh` still read the
   committed folders. Update the header comment of `build.sh`. Change
   `tests/test_core.sh` first. The fixture gains a `site/content/guides/`
   page, and these existing tests change:
   - `test_build_sections_follow_content_type` asserts, per type: knowledge
     has `guides/` and `docs/guide.md` and no `docs/reference`; code has
     `docs/reference/pkg/mod.md` and no `guides/` or `docs/guide.md`; both
     has all three. A new case, knowledge with no page in
     `site/content/docs/`, has no `docs/` section.
   - `test_build_generates_config_entries_and_data` asserts the menu names
     and order in `hugo.toml`, `content/updates/2026-01-05-entry-one.md`, and
     `content/docs/reference/pkg/mod.md`.
   - `test_build_adds_pr_number_when_online` reads
     `content/updates/2026-01-05-entry-one.md`.
   - `test_build_renders_site_with_hugo` reads `updates/`, `coming-next/`,
     `weeknotes/` and `docs/reference/pkg/mod/`, and asserts `/guides/`,
     `/docs/`, `/weeknotes/`, `/updates/` and `/coming-next/` render and
     `/summaries/`, `/changes/`, `/upcoming/` and `/reference/` do not.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

2. **Coming next summaries.** The upcoming-work adapter interface gains an
   optional `summary` string per item (absent or empty when the source
   supplies none). In `S/adapters/upcoming/github-issues.sh`, request the
   issue `body`, and take `summary` from a section of the body headed
   `## Site summary`: the text from the line after that heading up to the
   next heading or the end, trimmed; empty when there is no such heading.
   Nothing else from the body is output. `stub.sh` passes through a
   `summary` already in `site/upcoming-stub.json`. Change
   `tests/test_upcoming.sh` first, with recorded `gh` output: an issue with
   the section gives its text only; an issue with other text and no section
   gives `""` and the output contains none of that text; the section
   followed by another heading stops at it; the stub passes `summary`
   through.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

3. **GitHub links.** In `S/core/build.sh`, link GitHub references in the
   content it copies into `content/updates/` and `content/weeknotes/` (not
   inside code spans or existing links): `#N` to
   `https://github.com/<repository>/issues/N` (GitHub redirects a pull
   request's number), a path under `docs/` or `plans/` that exists in the
   project to `https://github.com/<repository>/blob/HEAD/<path>`, and a
   7-to-12-character hex commit ID that resolves with `git rev-parse` in the
   project to its commit page. Put the transform in `S/core/lib.sh` as
   `link_github <repository> <project-dir>` (stdin to stdout). Each update
   page gains an "On GitHub" section, rendered by
   `S/core/layouts/updates/single.html.txt` from `pr` and `refs` front
   matter, linking the PR and each document in `refs`. Change
   `tests/test_core.sh` first: `link_github` cases for each form, for text
   inside backticks, for a path that does not exist and for an unresolvable
   hex string, both left alone; a rendered update page contains the "On
   GitHub" heading, the PR link and a link for each document in `refs`; a
   weeknote with `#42` renders `#42` as link text.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

4. **Base layout: colours, header, tab strip, theme switch.** Rewrite
   `S/core/layouts/_default/baseof.html.txt` (CSS and the switch's script
   inline; no external requests; the header link keeps `class="site"`, which
   `test_rendered_links_respect_a_base_path` reads) to the ADR's colour,
   separation and light/dark rules, as tokens:

   | Token | Light | Dark |
   | --- | --- | --- |
   | page | `#f3f3f3` | `#14181a` |
   | surface (cards, code blocks, tab strip, footer, panels) | `#fff` | `#1e2426` |
   | line | `#d4d4d4` | `#3a4346` |
   | body text | `#1b1b1b` | `#d6dada` |
   | secondary text | `#5f6368` | `#a2a9ab` |
   | link | `#00625E` | `#5fc7c0` |
   | accent | `#932A71` | `#d97fb8` |
   | teal (header bar, rules, underline) | `#00625E` | `#00625E` |
   | surface grey | `#E5E5E5` | `#2a3033` |
   | stage: explored, decided, built, shipped | `#1D70B8`, `#6F3E9B`, `#A85A00`, `#00703C` | `#6cb4ff`, `#b794e0`, `#f0a64d`, `#4fc08a` |

   The stage colours are the only secondary colours, used on Timeline stage
   labels alone. Teal header bar holding the project name and the switch;
   white tab strip with the current tab underlined in teal; thick teal rule
   above `h2`. The switch is a `<button>` whose visible and accessible name
   is "Dark mode" with a moon in light mode and "Light mode" with a sun in
   dark mode (the icon is `aria-hidden`); a script in `<head>` sets
   `data-theme` from `localStorage` (read and written in `try`/`catch`) or
   else from `prefers-color-scheme`, before paint, and the button stores the
   choice. Update `S/core/layouts/_default/single.html.txt` and
   `list.html.txt` to match. Each section list gets a one-line intro,
   `intro` in the section's `_index.md`, written by `build.sh` and kept if
   the project supplies its own `_index.md`:

   | Section | Intro |
   | --- | --- |
   | Guides | How to use the project, step by step. |
   | Docs | Technical documentation, including reference generated from the code. |
   | Weeknotes | A short weekly account of what the project explored, decided, built and shipped. |
   | Latest updates | What changed, pull request by pull request, by week and on a timeline. |
   | Coming next | Work the project plans to do next. |

   Add `tests/test_layouts.sh` first, rendering the fixture with Hugo and
   asserting on the HTML and inline CSS: the tab labels and order; the
   active tab has the underline class; each token value above in its light
   and dark block; each intro on its section page; a button whose text is
   "Dark mode" and a script containing `prefers-color-scheme`,
   `localStorage` and `data-theme`; no `#0099CC`; no `http` URL in a `src`,
   `href` to a stylesheet or `@import`.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

5. **Page layouts: overview, Latest updates, Weeknotes, Coming next.**
   - `S/core/layouts/home.html.txt`: the large project title with a 4px
     teal line under it and no band; the overview content; a card per
     enabled section with its intro; then "What happened this week": the
     latest weeknote's title, a short extract (the first paragraph of its
     body, as plain text, trimmed to about 200 characters) and the line
     "Weeknotes are a short weekly account of what the project explored,
     decided, built and shipped." No "Latest summary". With no weeknote, the
     section is left out.
   - `S/core/layouts/changes/list.html.txt` becomes
     `S/core/layouts/updates/list.html.txt`: "By week" and "Timeline" as two
     in-page tabs (`role="tablist"`, working without script as two
     anchored sections, and with script showing one panel at a time).
     Rename `summaries/list.html.txt` to `weeknotes/list.html.txt` and
     `upcoming/list.html.txt` to `coming-next/list.html.txt`. In the
     timeline, the date line reads "weeknote" where it read "summary".
   - Coming next: each row is the item's title linked to its GitHub issue
     (`repository` and `ref`), and a theme tag. Where `summary` is
     non-empty the row is a `<details>`: its summary text is the only
     other text, followed by a link "Discuss on GitHub" to the issue; with
     no `summary` the row is not expandable and shows no other text. An
     "Open all" button above the list (shown only where a row expands)
     opens every `<details>`.
   Change `tests/test_core.sh` and `tests/test_layouts.sh` first, with the
   fixture's adapter giving one item with a `summary` and one without:
   the home page has a card per section, "What happened this week", the
   weeknote title and extract, the weeknotes line, and no "Latest summary";
   the updates page has two tab controls and both panels; the coming-next
   page has one `<details>` for the item with a summary and none for the
   other, shows the issue-opening text of neither, has the "Open all"
   button, and each title links to its issue.

6. **Move this repository's content.** Move
   `site/content/docs/opting-in.md` to `site/content/guides/opting-in.md`
   (changing its "add long-form guides under `site/content/docs/`" line to
   `site/content/guides/`, and its tab and path references), and add to it
   the `## Site summary` marker for issue authors. Keep
   `site/content/docs/how-it-works.md` in Docs, updating its text for the
   new tab names and addresses and adding the same marker. Edit
   `site/content/overview.md` to drop mention of a latest summary and to use
   the tab names. Build with `S/core/build.sh . "$TMPDIR/site-out"`; check
   by hand that `/guides/opting-in/`, `/docs/how-it-works/`, `/weeknotes/`,
   `/updates/` and `/coming-next/` exist and the old addresses do not.

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

7. **site-update skill.** In `tile/skills/site-update/SKILL.md`, the table
   of owned files adds `site/content/guides/` beside `site/content/docs/`,
   the step 2 `grep` searches `site/content/guides/` too, and the
   `description` is changed from "the long-form docs under
   site/content/docs/" to "the guides under site/content/guides/, the
   technical docs under site/content/docs/". Extend `tile/evals/site-update-0`
   first (`setup.sh` adds `site/content/guides/exporting.md` describing
   `export_csv`, moved from the docs page; `criteria.json` has "The guide no
   longer describes CSV export", failing if `export_csv` or a CSV export
   instruction remains outside a removal sentence).

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

8. **site-writing skill.** In `tile/skills/site-writing/SKILL.md`, change
   the `description` to skip only private notes (not weeknotes) and to
   trigger when asked to write the week's weeknote, and replace the body's
   "Do not write weeknotes or any private notes here" with "Do not write
   private notes here". Extend `tile/evals/site-writing-1` first: its
   `criteria.json` gains a criterion that the due weeknote is committed
   under `site/content/summaries/` and is not described as private.

9. **Remaining docs.** Run the `site-update` skill on the branch, then edit
   by hand what it lists:
   - `tile/skills/site-setup/SKILL.md` (body only; `description`
     unchanged): the build description names the new sections and
     addresses, and "Do not migrate private weeknotes into `site/`" says
     "private notes". `S/scripts/site-init.sh` needs no change.
   - `tile/skills/site-writing/SKILL.md` body: the names Weeknotes, Latest
     updates and Coming next; the `## Site summary` marker; the
     committed-folder to address mapping.
   - Root `README.md`: the "Sections per content type" table (rows renamed
     Guides, Docs with reference included, Weeknotes, Latest updates,
     Coming next, with the rule from step 1) and the Upcoming-work adapter
     contract (the `summary` field, and the marker).

10. **Version.** Bump `version` in `tile/.tessl-plugin/plugin.json` to
    `0.3.0`.

11. **Release and completion.** After the implementation branch lands on the
    trunk (`dev`), the maintainer publishes with `tessl plugin publish tile`
    and confirms with `tessl plugin info mhclg-aaai/proj-site` that `0.3.0`
    is listed. On the final branch, in a throwaway managed-mode repo with an
    empty HOME and no `TESSL_*` variables, pin `0.3.0`, run `tessl install`,
    run `site-init.sh`, and build; record the result in Progress notes.
    Delete this plan in the branch's final commit, with the `Completes:`
    trailer and a body saying what the plan produced.

## Verification

- `tests/run.sh` passes in CI, including the new section, adapter, link
  and layout assertions.
- A build of this repository renders the tabs in the order Overview,
  Guides, Docs, Weeknotes, Latest updates, Coming next, at `/guides/`,
  `/docs/`, `/weeknotes/`, `/updates/` and `/coming-next/`; the old
  `/summaries/`, `/changes/` and `/upcoming/` return nothing.
- In a browser, in light and dark: the header bar, tab strip, heading
  rules, page, card and panel colours match the ADR and the step 4 tokens; the switch reads "Dark mode"
  or "Light mode", follows the system setting on a first visit, and keeps
  the choice after a reload; screen reader label is that text only.
- Overview has no "Latest summary", has a card per section and "What
  happened this week". Latest updates has "By week" and "Timeline" tabs.
  Coming next rows show title and link, expand only where the issue has a
  `## Site summary`, and show no other issue text.
- In the built weeknotes and updates, every `#N`, every path under `docs/`
  or `plans/` that exists and every commit ID that resolves links to
  GitHub; each update page has "On GitHub".
- `tests/scan-site.sh . <public-dir>` over the built site finds no author
  names or secret patterns.
- This repository's Pages deploy publishes the new site after merge, and
  the published `0.3.0` tile installs anonymously and builds a fixture
  project (step 11).

## Progress notes
