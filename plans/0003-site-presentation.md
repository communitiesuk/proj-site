---
title: Present the project site with the new tabs, colours and links
status: in-progress
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
set the web addresses. Steps 1 to 11 land on one implementation branch. The
maintainer publishes from the trunk (step 12), and the rest of step 12 lands
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
   Latest updates, Coming next, with `menus.main` names set explicitly. Section index titles match the
   tab names. Guides is enabled for `knowledge` and `both`. Docs is enabled
   for `code` and `both`, and for `knowledge` when `site/content/docs/`
   holds a page other than `_index.md`; hand-written pages are copied for
   `knowledge` and `both`, not `code`. The `menu` list in `build.sh`, and the `for always in changes
   summaries upcoming` loop in `tests/test_core.sh`, become updates,
   weeknotes and coming-next. `check-pr.sh`, the hooks and the skills still
   read the committed folders; `timeline.sh` reads git and is unchanged.
   `build.sh` copies the whole `S/core/static/` directory, where it exists,
   to `src/static/`. Rename the layouts: `S/core/layouts/changes/` to
   `updates/`, `summaries/` to `weeknotes/` and `upcoming/` to `coming-next/`.
   Update the header comment of `build.sh`. First move `make_chain_repo` and `make_project` from
   `tests/test_core.sh` to `tests/lib.sh`, so `tests/test_layouts.sh` can use
   them. Then change `tests/test_core.sh`: the fixture gains a
   `site/content/guides/` page, and these existing tests change:
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

2. **Coming next summaries and dates.** The upcoming-work adapter interface
   gains an optional `summary` string and an optional `date` (`YYYY-MM-DD`)
   per item, each absent or empty when the source supplies none. In
   `S/adapters/upcoming/github-issues.sh`, request the issue `body` and
   `createdAt`. Take `summary` from a section of the body headed
   `## Site summary`: the text from the line after that heading up to the
   next heading or the end, trimmed; empty when there is no such heading.
   Nothing else from the body is output. Take `date` from the first ten
   characters of `createdAt` (the day the issue was opened, UTC). An item's
   theme stays the first `theme:<x>` label, as now; an item without one has
   `theme` `""`. Update the script's header comment. `stub.sh` needs no
   change: it passes `site/upcoming-stub.json` through. Change
   `tests/test_upcoming.sh` first, with recorded `gh` output:
   `test_theme_label_extracted` expects `"summary":""` and the recorded
   `date`; `gh.args` contains `body` and `createdAt`; an issue with the
   section gives its text only; an issue with other text and no section
   gives `""` and the output contains none of that text; the section
   followed by another heading stops at it.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

3. **GitHub links.** In `S/core/build.sh`, link GitHub references in the
   body of every page it copies into the build (overview, Guides, Docs,
   updates, weeknotes; front matter is left as written, and not inside code
   spans, fenced code blocks or existing links): `#N` to
   `https://github.com/<repository>/issues/N` where `#N` is not followed by a
   letter or digit, a path under `docs/` or `plans/` that exists at HEAD in
   the project, is not preceded by a letter, digit, `/`, `.`, `-` or `_` and
   is not followed by a letter, digit or `/`, to
   `https://github.com/<repository>/blob/HEAD/<path>` (a path absent at HEAD
   stays plain text), and a 7-to-12-character hex commit ID that stands
   alone (no letter or digit before or after it) and resolves with
   `git rev-parse --verify <hex>^{commit}` in the project to its commit page. Put the transform in `S/core/lib.sh` as
   `link_github <repository> <project-dir>` (stdin to stdout). `build.sh`
   also writes each update's `refs` as `ghrefs` front matter, each entry a
   label and a URL: the issue page for `#N`, the blob URL for a path
   present at HEAD, and no URL for a path absent at HEAD. Each update page
   gains an "On GitHub" section, rendered by
   a new `S/core/layouts/updates/single.html.txt` from `pr` and `ghrefs`, linking
   the PR and each entry with a URL and listing the rest as plain text. In
   the Timeline (`S/core/layouts/updates/list.html.txt`), each event's commit ID and its
   path link to `https://github.com/<repository>/commit/<commit>`. Change
   `tests/test_core.sh` first (the shared `make_project` fixture's entry `refs` gain
   `#42`, `docs/adr/0001-choice.md` and `plans/0001-build.md`, the last absent at
   HEAD, and the weeknote, overview, guide and doc bodies gain a `#42`):
   `link_github` cases for each form, for text
   inside backticks and inside a fenced block, for a path absent at HEAD,
   an unresolvable hex string, a path inside a longer one
   (`mydocs/x.md`), `#42a` and a 13-character hex string, all left alone, and for front matter containing `#42`,
   left unchanged; with `SITE_OFFLINE=0` and a stub `SITE_GH` (as
   `test_build_adds_pr_number_when_online` does), a rendered update page
   contains the "On GitHub" heading, the PR link, a link for a `#42` ref and
   for a ref path present at HEAD, and the path absent at HEAD as plain
   text; a weeknote with `#42` renders `#42` as link text; the rendered
   overview, a guide and a doc each link a `#N`; the Timeline links a
   commit ID and its path to the commit page.

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
   | recent (Timeline highlight) | `#fff7d6` | `#3a3320` |
   | stage: explored, decided, built, shipped | `#1D70B8`, `#6F3E9B`, `#A85A00`, `#00703C` | `#6cb4ff`, `#b794e0`, `#f0a64d`, `#4fc08a` |

   The stage colours are the only secondary colours, used on Timeline stage
   labels alone. Teal header bar holding the project name and the switch;
   white tab strip with the current tab underlined in teal; thick teal rule
   above `h2`, with more space around it. The switch is a `<button>` whose visible and accessible name
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

   Add `tests/test_layouts.sh` first, using the fixtures in `tests/lib.sh`,
   rendering the fixture with Hugo and
   asserting on the HTML and inline CSS: the tab labels and order; the
   active tab carries `aria-current="page"`; each token value above in its light
   and dark block; each intro on its section page; a button whose text is
   "Dark mode" and a script containing `prefers-color-scheme`,
   `localStorage` and `data-theme`; no `http` URL in a `src`,
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
   - `S/core/layouts/updates/list.html.txt`: "By week" and "Timeline" as two
     in-page tabs (`role="tablist"`, working without script as two
     anchored sections, and with script showing one panel at a time). In the
     timeline's intro paragraph, "since the last summary" becomes "since
     the last weeknote".
   - Coming next: the rows are grouped by theme, each group an `h3` with
     the theme above its rows, groups in alphabetical order of theme, items
     with no theme in a last group headed "No theme"; within a group, oldest
     `date` first, items with no `date` last. Each row is the item's title
     linked to its GitHub issue (`repository` and `ref`) and, where `theme`
     is non-empty, a theme tag, and carries `data-item-theme` and `data-date`
     attributes. Where `summary` is
     non-empty the row is a `<details>`: its summary text is the only
     other text, followed by a link "Discuss on GitHub" to the issue; with
     no `summary` the row is not expandable and shows no other text. An
     "Open all" button above the list, rendered only where a row expands and
     with `hidden` (the step 6 script shows it), opens every `<details>`.
   Change `tests/test_core.sh` and `tests/test_layouts.sh` first, with the
   fixture's adapter giving four items, each with a `body` of
   issue-opening text: A (theme Alpha, date 2026-01-03, with a `summary`),
   B (theme Beta, date 2026-01-01, no `summary`), C (no theme, no date, no
   `summary`) and D (theme Alpha, date 2026-01-02, no `summary`). The titles
   change from `UPCOMING-ITEM`, so `test_build_generates_config_entries_and_data`
   (its `data/upcoming.json` title) and `test_build_renders_site_with_hugo`
   (its coming-next page) take the new titles:
   the home page has a card per section, "What happened this week", the
   weeknote title and extract, the weeknotes line, and no "Latest summary";
   the updates page has two tab controls labelled "By week" and "Timeline"
   and both panels; the coming-next page lists D, A, B, C in that order under `h3`s Alpha, Beta
   and "No theme", has one `<details>` (A's), shows no `body`, has the "Open
   all" button with `hidden`, links each title to its issue, and shows a
   theme tag on A, B and D and none on C.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

6. **Coming next controls.** Users can group by theme, order by date, and
   include or exclude themes, in the browser, with no request to another
   site. The choices:
   - Theme comes from the item's `theme` (the `theme:<x>` label for GitHub
     issues). An item without one has no tag and is called "No theme" in
     the controls and as a group.
   - The date that orders the table is the item's `date`: the day the issue
     was opened. An item with no `date` comes after those with one, in
     either direction.
   - The default view, and the only view without script, is step 5's:
     all themes, grouped by theme, oldest first within each group. The
     controls start from it, and Reset returns to it.
   - The controls apply together: first themes are filtered, then the rest
     are grouped (groups in alphabetical order of theme, "No theme" last)
     or not, then ordered by date within each group, or across the list.
   - Look: a bordered surface panel above the list holding a "Group by
     theme" checkbox (checked at first), an "Order by date" select
     ("Oldest first", "Newest first"), a "Show themes" set of checkboxes,
     one per theme present (with "No theme" last, only where an item lacks
     one), all checked at first (an unchecked theme is excluded), and a
     "Reset" button. With every theme unchecked the list is replaced by "No
     items match." The panel uses the step 4 tokens.
   - The template renders the panel from the upcoming data, with `hidden`,
     only where there are two or more items; the script removes `hidden`
     from it and from "Open all", and wires them.

   Put the logic in `S/core/static/coming-next.js` as a function
   `arrange(items, options)` (items with `theme`, `date` and `index`, the
   item's position in the rendered list, which breaks ties between equal
   dates; options `group`, `order`, `excluded`; returns the groups, each with
   a theme or `null` and its items) with no use of the page, exported for
   Node when `module` exists; the rest of the file reads the rows'
   `data-item-theme` and `data-date`, calls `arrange` and rearranges the
   existing rows and group headings. Step 1's copy of `S/core/static/` puts
   it in `src/static/`. `S/core/layouts/coming-next/list.html.txt` loads it
   with `<script src="{{ "coming-next.js" | relURL }}">` and renders the
   panel. Add `tests/test_coming_next.sh` first. It fails with a message when
   `command -v node` fails (the CI runner has Node installed) and runs
   `arrange` under Node: the default options give step 5's order; ungrouped,
   oldest and newest first with an undated item last in both; grouping, with
   "No theme" last; excluding one theme, then all; every control at once.
   In `tests/test_layouts.sh`, with step 5's fixture: the built
   `coming-next/index.html` has the panel with `hidden`, "Group by theme"
   checked, a checked checkbox for Alpha, Beta and "No theme", the select
   options and the script tag, and "Open all" with `hidden`;
   `public/coming-next.js` exists; the rows are in step 5's order in the
   HTML, so the page reads correctly with no script; with an adapter giving
   one item, the page has no panel. The DOM wiring is not run under Node; it
   is checked in a browser (Verification).

7. **Move this repository's content.** Move
   `site/content/docs/opting-in.md` to `site/content/guides/opting-in.md`
   (changing its "add long-form guides under `site/content/docs/`" line to
   `site/content/guides/`, and its tab and path references; its "Existing
   weeknotes are not migrated" sentence to name the gitignored `weeknotes/`
   folder), and document in it the `## Site summary` marker for issue authors.
   Keep `site/content/docs/how-it-works.md` in Docs, updating its text for
   the new tab names and addresses and documenting the same marker, and
   where a Coming next item's theme and date come from. Edit
   `site/content/overview.md` to drop mention of a latest summary and to use
   the tab names. Build with `S/core/build.sh . "$TMPDIR/site-out"`; check
   by hand that `/guides/opting-in/`, `/docs/how-it-works/`, `/weeknotes/`,
   `/updates/` and `/coming-next/` exist and the old addresses do not.

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

8. **site-update skill.** In `tile/skills/site-update/SKILL.md`, the table
   of owned files adds `site/content/guides/` beside `site/content/docs/`,
   the step 2 `grep` searches `site/content/guides/` too, and the
   `description` is changed from "the long-form docs under
   site/content/docs/" to "the guides under site/content/guides/, the
   technical docs under site/content/docs/". Extend `tile/evals/site-update-0`
   first: `setup.sh` creates `site/content/guides/exporting.md` (moved from
   `site/content/docs/`) describing `export_csv`; criterion 1 and the
   `context` score `site/content/guides/exporting.md` (or its successor under
   `site/content/guides/`), and criterion 3 keeps checking both it and the
   overview.

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

9. **site-writing skill.** In `tile/skills/site-writing/SKILL.md`, change
   the `description` to skip the gitignored `weeknotes/` folder a project
   keeps private (not weeknotes in general) and to trigger when asked to
   write the week's weeknote, and replace the body's "Do not write weeknotes
   or any private notes here" with "Do not write into the gitignored
   `weeknotes/` folder; everything under `site/` is public". Add
   `tile/evals/site-writing-2` first (`scenario.json`; `setup.sh` as
   `site-writing-1`'s; `task.md` asks for this week's weeknote for `lantern`,
   left committed on `feature-date-filter`, and says nothing about where it
   goes;
   `criteria.json` scores that the due `site/content/summaries/<DUE>.md`
   (DUE as in `site-writing-1`) is committed on `feature-date-filter`,
   failing if none is).

10. **Remaining docs.** Run the `site-update` skill on the branch, then edit
   by hand what it leaves stale:
   - `tile/skills/site-setup/SKILL.md` (body only; `description`
     unchanged): the build description names the new sections and
     addresses, and "Do not migrate private weeknotes into `site/`" says
     "Do not migrate the gitignored `weeknotes/` folder into `site/`".
   - `S/scripts/site-init.sh` (header comment only): "no existing weeknotes
     are migrated" names the gitignored `weeknotes/` folder.
   - `tile/skills/site-writing/SKILL.md` body: the names Weeknotes, Latest
     updates and Coming next; the `## Site summary` marker; the
     committed-folder to address mapping.
   - Root `README.md`: the "Sections per content type" table (rows renamed
     Guides, Docs with reference included, Weeknotes, Latest updates,
     Coming next, with the rule from step 1) and the Upcoming-work adapter
     contract (the `summary` and `date` fields, and the marker).

11. **Version.** Bump `version` in `tile/.tessl-plugin/plugin.json` to
    `0.3.0`.

12. **Release and completion.** After the implementation branch lands on the
    trunk (`dev`), the maintainer publishes with `tessl plugin publish tile`
    and confirms with `tessl plugin info mhclg-aaai/proj-site` that `0.3.0`
    is listed. On the final branch, in a throwaway managed-mode repo with an
    empty HOME and no `TESSL_*` variables, pin `0.3.0`, run `tessl install`,
    run `site-init.sh`, and build; record the result in Progress notes and
    commit it. Delete this plan in the branch's last commit, after that one, with the `Completes:`
    trailer and a body saying what the plan produced.

## Verification

- `tests/run.sh` passes in CI, including the new section, adapter, link,
  layout and coming-next (`tests/test_coming_next.sh`, Node) assertions.
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
  Coming next rows, grouped by theme and oldest first within a group, show
  title, link and theme tag, expand only where the issue has a
  `## Site summary`, and show no other issue text.
- In a browser, on a build with items of at least two themes and one with
  no theme or date, in light and dark: the controls panel and "Open all" are shown; "Group
  by theme", "Order by date", each theme checkbox and "Reset" (back to the
  grouped, oldest-first default) act as step 6 says, alone and together;
  with script disabled the panel and "Open all" are hidden and the list
  shows grouped in the default order; with one item there is no panel; the browser's network panel shows
  no request to another site.
- In every built page, outside code, front matter and existing links, per step 3, every `#N`, every path under `docs/` or `plans/`
  that exists at HEAD and every commit ID that resolves links to GitHub;
  each Timeline commit ID and path links to its commit page; each update
  page has "On GitHub".
- `tests/scan-site.sh . <public-dir>` over the built site finds no author
  names or secret patterns.
- This repository's Pages deploy publishes the new site after merge, and
  the published `0.3.0` tile installs anonymously and builds a fixture
  project (step 12).

## Progress notes
