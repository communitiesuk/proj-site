---
title: Build the automatically maintained project site
status: draft
adr: 0001
date: 2026-11-23
deferred_reason: null
---

# Build the automatically maintained project site

Implements [ADR 0001](../docs/adr/0001-project-site.md).

## Steps

1. **Hugo spike.** Build a throwaway Hugo site in a scratch directory
   that renders three things: a page from hand-written Markdown, a
   per-PR entry list grouped by week from front matter, and generated
   reference docs for one language. Check that it installs as a single
   binary in a GitHub Actions runner and deploys to GitHub Pages. The
   spike's outcome is "Hugo confirmed" or a named replacement from the
   ADR's alternatives. Record the outcome in Progress notes. If Hugo is
   replaced, read "Hugo" below as the replacement. Commit: the notes
   only; the scratch site is discarded.

2. **Layout and content model.** Fix, as a short spec in this repo's
   `README.md`, what an opted-in project holds:
   - `site/config` (project name, repository, content type: `knowledge`,
     `code` or `both`, languages);
   - `site/content/overview.md` and `site/content/docs/` (hand-written);
   - `site/content/changes/<branch-slug>.md`, one per PR, with front
     matter `title`, `date`, `pr` (null until the PR exists), `theme`,
     `refs` (ADR, plan, issue and PR references) and a plain-language
     body in the explored, decided, built, shipped order;
   - `site/content/summaries/<YYYY>-W<WW>.md`, one per period, with front
     matter `period_start`, `period_end`, `counts`, and sections by
     theme, "Completed" and "In flight / queued" in the weeknotes
     style.
   The spike's outcome fixes the exact directory names if Hugo is
   replaced.

3. **Sections per content type.** The content type enables sections:
   - `knowledge`: overview, long-form docs, changes, summaries,
     upcoming;
   - `code`: overview, long-form docs, reference docs, changes,
     summaries, upcoming;
   - `both`: all of the above.
   Changes, summaries and upcoming appear for every type, as they serve
   stakeholders.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

4. **Core.** Write the scripts that build the site: read the git graph
   (ADRs, plans, `Derives-From`, `Consumed-By`, `Completes`,
   `Abandons` trailers) to produce done and recently completed work,
   merge in the per-PR entries and summaries, and generate Hugo
   content. Tests use a fixture git repository with a known trailer
   chain. Files: `core/` and its tests.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

5. **Upcoming-work adapter.** Define the adapter interface (returns a
   list of items with title, reference, state, and theme) and write the
   GitHub issues implementation behind it, run through `gh`. The core
   calls only the interface. Tests use a stub source and recorded `gh`
   output.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

6. **Reference-docs adapters.** Define the adapter interface (project
   path in, Markdown or Hugo content out) and write the first adapters
   for Python (docstrings) and TypeScript (TSDoc), the languages used
   in myelin projects. Further languages follow as separate plans. Each
   adapter is enabled by the `languages` setting. Tests run each
   adapter on a small fixture module.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

7. **CI check script.** Write a script run on `pull_request`, with no
   agent involved. It fails the PR when:
   - the PR's diff adds no file under `site/content/changes/`;
   - a weekly summary is due and missing. A summary is due when the PR
     date (UTC) is a Thursday or later in its ISO week and no file
     `site/content/summaries/<YYYY>-W<WW>.md` for that week exists on
     the trunk or in the PR's diff. This covers the first PR on a
     Thursday and the next PR after that, until one is produced.
   Failure messages name the missing file and the skill that writes it.
   Tests cover: no entry; entry only; Thursday with and without a
   summary; Wednesday; summary added by the PR itself; a week boundary.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

8. **Content-rule check.** Extend the CI script to flag, in new
   per-PR entries and summaries, common secret patterns and the
   `git log` author names of the repository. Internal-event mentions
   and the rest of the public content rules are left to the writing
   skill; the check does not claim to enforce them.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

9. **Workflows.** Add templates for two GitHub workflows: the
   `pull_request` workflow that runs the CI check, and the Pages
   workflow that builds with the core and deploys to GitHub Pages on
   merge to the trunk. Verify both on a test repository (see
   Verification).

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

10. **Writing skill.** Author a skill triggered before raising a PR. It
    writes the per-PR entry at `site/content/changes/<branch-slug>.md`
    from the branch's commits and trailer chain, and, when a summary
    is due by the CI check's rule, writes the summary for the period
    from the entries and the upcoming-work adapter. It can also be
    invoked manually to produce a summary. It applies the public
    content rules: no named people, internal events only where they
    publicised the project, no secrets. Its eval scenarios include a
    branch with a named author in its commits and a due summary.

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

11. **Update skill.** Author a skill that compares the overview,
    long-form docs and reference docs with what exists in the project
    and proposes edits to bring them into line. Its eval scenarios
    include a doc describing a removed feature.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

12. **Optional Claude Code hook.** Add a hook configuration that runs
    the writing skill before a PR is raised. It is optional, and
    CI remains the enforcement. Only Claude Code is supported.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

13. **Opt-in and distribution.** Write the opt-in script that installs
    the skills, scripts, CI workflow and Pages workflow into a myelin
    project, creates `site/` with the config for its content type, and
    is safe to re-run. Existing weeknotes are not migrated on opt-in:
    the script does not read `../myelin/weeknotes`, and the first
    summary is written by the writing skill from the git graph.
    Tests run the script on a fixture project twice.

14. **Pilot.** Opt in this repository and one other myelin project on
    GitHub. Raise a PR in each and confirm: the check fails without an
    entry, passes with one, the Pages deploy publishes, and the first
    summary is produced and passes the check.

15. **Completion.** Delete this plan in the final commit with the
    `Completes:` trailer and a body saying what the plan produced.

## Verification

- All unit tests pass in CI on this repository.
- On a test repository with a Pages workflow: a PR with no per-PR entry
  fails the check; adding the entry passes it; on a Thursday or later a
  PR with no summary for the week fails until one is added; merging
  deploys a site that shows overview, the sections its content type
  enables, per-PR entries, a summary, and upcoming items from GitHub
  issues.
- Replacing the upcoming-work source with the stub changes the
  upcoming list without any core change.
- A scan of the published site for named people and secrets finds none.

## Progress notes

None yet.
