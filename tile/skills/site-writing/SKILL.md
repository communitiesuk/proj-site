---
name: site-writing
description: Writes the public project site's stakeholder content in a project opted into proj-site — the per-PR entry under site/content/changes/ and, when one is due, the weeknote (the weekly summary) under site/content/summaries/ — following the public content rules. TRIGGER before raising or opening a pull request in a repository that has site/project.yaml, when the site check reports a missing entry or a due summary, or when asked to write the week's weeknote or summary. SKIP for repositories without site/project.yaml, for editing the overview, guides or docs to match the code (use the `site-update` skill), and for the gitignored `weeknotes/` folder a project keeps private.
---

# Site writing

The project's public site tells stakeholders what was explored, decided, built and shipped. You write two kinds of file for it, both committed on the branch before the pull request is raised, so they are reviewed with the change:

- a **per-PR entry**, on every branch;
- a **weekly summary**, on the first branch raised once one is due.

A CI check (`skills/site-setup/scripts/check-pr.sh` in this tile) fails the pull request when either is missing. It only checks that the files exist; what they say is yours to get right.

The harness states this skill's base directory when it loads the skill. Call it `$SKILL_DIR`; the tile's scripts are in `$SKILL_DIR/../site-setup/scripts/`.

## Public content rules

Everything under `site/` is published. Apply these to every word you write there:

1. **No named people.** No names, handles or email addresses — not the commit author, not a colleague thanked in a commit body, not a reviewer. Write "the team" or describe the work instead.
2. **Internal events only where they publicised the project** — a show and tell or a talk about it. Leave out internal meetings, stand-ups and pairing.
3. **No secrets.** No tokens, keys, internal hostnames or credentials, even partial.

Commit messages are source material, not text to copy: read them for what changed, then write the outcome in your own words.

## 1. The per-PR entry

1. Read the branch's commits against the trunk (`git log <trunk>..HEAD`), their trailers, and the artefacts they add or change (ADRs, plans, discovery notes).
2. Write `site/content/changes/<YYYY-MM-DD>-<branch-slug>.md`:
   - `<YYYY-MM-DD>` is today's date in UTC (`date -u +%F`).
   - `<branch-slug>` is the branch name, lower-cased, with anything other than letters, digits and hyphens replaced by `-`.
   - If that file already exists on the trunk, append `-2`, `-3`, … rather than editing it. An existing entry belongs to an earlier PR.
3. Front matter, then a body:

   ```markdown
   ---
   title: <the outcome, in plain language, as a reader would want it>
   date: <the same YYYY-MM-DD as the filename>
   theme: <a short theme, reused from recent entries where one fits>
   refs: ["docs/adr/0002-example.md", "plans/0003-example.md", "#42"]
   ---
   <Two to five sentences, in explored, decided, built, shipped order, saying
   what changed for users or stakeholders and why.>
   ```

   `refs` lists every ADR, plan and discovery note the branch adds, changes or completes, and any issue it closes. Leave out stages that do not apply.
4. Commit the entry on the branch.

## 2. The weekly summary, when due

1. Find the due week: `bash "$SKILL_DIR/../site-setup/scripts/check-pr.sh" --due-week` prints it, for example `2026-W01`. It is the ISO week (`%G-W%V`, UTC) containing the most recent Thursday 00:00 UTC. Do not compute it from today's calendar week.
2. The summary is **due** when `site/content/summaries/<due-week>.md` is not on the trunk and not in another open pull request (`gh pr list --state open --json files`, where `gh` is available). If it is not due, stop: write the entry only.
3. Write `site/content/summaries/<due-week>.md`, covering the period since the previous summary's `period_end` (or since the project began, for the first):

   ```markdown
   ---
   title: Week of <the Thursday, YYYY-MM-DD>
   period_start: <YYYY-MM-DD>
   period_end: <today, YYYY-MM-DD>
   counts: {prs: <merged PRs in the period>, issues_closed: <issues closed>}
   ---
   <One paragraph: the headline of the period.>

   ## <Theme>
   - <Outcome in plain language> (#<PR>)

   ## Completed
   - <Outcome> (#<PR>, docs/adr/NNNN-...)

   ## In flight / queued
   - <Open work, from open issues and in-flight branches> (#<issue>)
   ```

   Draw "Completed" from the per-PR entries and the git history in the period, and "In flight / queued" from open issues (`gh issue list --state open`). Where `gh` is unavailable, use the git history and the plans in `plans/` for both sections, and leave `counts` at what git shows. Group by theme, not by artefact type. Apply the public content rules.
4. Asked to write the summary on demand when the due week's file already exists, update that file rather than creating another.
5. Commit the summary on the branch, separately from the entry.

## 3. Check before raising

Run the check the CI runs, and fix what it reports before raising the pull request:

```sh
bash "$SKILL_DIR/../site-setup/scripts/check-pr.sh" --base <trunk> --head HEAD
```

## Do not

- Do not copy commit messages, names or thanks into `site/`.
- Do not edit an earlier PR's entry to stand in for this one.
- Do not name the summary from today's week number or from `%Y`; use the due week.
- Do not leave the files uncommitted; the check reads the branch, not the working tree.
- Do not write into the gitignored `weeknotes/` folder; everything under `site/` is public.

## When you may deviate

- **No `site/project.yaml`**: the repository has not opted in; this skill does not apply.
- **The branch only changes `site/` content you are writing now**: it still gets its own entry.
