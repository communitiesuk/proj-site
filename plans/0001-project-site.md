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
   spike's outcome is "Hugo confirmed" or a named replacement. Record
   the outcome in Progress notes. If Hugo is replaced, read "Hugo"
   below as the replacement. Commit: the notes only; the scratch site
   is discarded.

2. **Layout and content model.** Create `README.md` with a short spec
   of what an opted-in project holds:
   - `site/project.yaml` (project name, repository, content type:
     `knowledge`, `code` or `both`, `languages`, `upcoming.source`);
   - `site/content/overview.md` and `site/content/docs/`
     (hand-written);
   - `site/content/changes/<branch-slug>.md`, one per PR, with front
     matter `title`, `date`, `theme`, `refs` (ADR, plan and issue
     references) and a plain-language body in the explored, decided,
     built, shipped order. The core derives the PR number at build
     time from the merge commit;
   - `site/content/summaries/<%G>-W<%V>.md` (ISO week, UTC), one per
     period, with front matter `period_start`, `period_end`, `counts`,
     and sections by theme, "Completed" and "In flight / queued" in the
     weeknotes style. A summary covers the period since the previous
     summary;
   - generated content is written at build time into an uncommitted
     build directory.
   Sections per content type: `knowledge` enables long-form docs;
   `code` enables reference docs; `both` enables both; overview,
   changes, summaries and upcoming are always enabled. The spike's
   outcome fixes the exact directory names if Hugo is replaced.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

3. **Core.** Write the scripts that build the site: read the git graph
   (ADRs, plans, `Derives-From`, `Consumed-By`, `Completes`,
   `Abandons` trailers) to produce done and recently completed work,
   merge in the per-PR entries and summaries, and generate Hugo
   content. Tests use a fixture git repository with a known trailer
   chain and assert the sections each content type enables. Files:
   `core/` and its tests.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

4. **Upcoming-work adapter.** Define the adapter interface (returns a
   list of items with title, reference, state, and theme) and write the
   GitHub issues implementation behind it, run through `gh` and
   selected by `upcoming.source`. The core calls only the interface.
   Tests use a stub source and recorded `gh` output.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

5. **Reference-docs adapter.** Define and document the adapter
   interface (project path in, Markdown or Hugo content out) and write
   the first adapter, for Python (docstrings). Further languages follow
   as separate plans. Each adapter is enabled by the `languages`
   setting. Tests run the adapter on a small fixture module.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

6. **CI check script.** Write a script run on `pull_request`, with no
   agent involved. It fails the PR when:
   - the PR's diff adds no file under `site/content/changes/`;
   - a weekly summary is due and missing. A summary is due when the PR
     date (UTC) is a Thursday or later in its ISO week and no file
     `site/content/summaries/<%G>-W<%V>.md` for that week exists on
     the trunk or in the PR's diff. A week with no PR from Thursday on
     gets no summary; the next summary covers the period since the last
     one.
   Failure messages name the missing file and the skill that writes it.
   Tests assert: no entry fails; entry only on a Monday passes; Thursday
   without a summary fails; Thursday with a summary on the trunk passes;
   Wednesday passes; summary added by the PR itself passes; a PR on
   Sunday 2026-01-04 and one on Monday 2026-01-05 resolve to weeks
   `2026-W01` and `2026-W02` respectively.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

7. **Workflows.** Add templates for two GitHub workflows: the
   `pull_request` workflow that runs the CI check, and the Pages
   workflow that builds with the core and deploys to GitHub Pages on
   merge to the trunk. Both check out with `fetch-depth: 0`; the Pages
   workflow has a token with issues read access, and the opt-in
   documentation says to enable Pages for the repository. Verify both
   on a test repository (see Verification).

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

8. **Test workflow.** Add `.github/workflows/test.yml` for this
   repository, running the unit tests of every step on `pull_request`
   and on push to the trunk.

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

9. **Writing skill.** Author `skills/site-writing/SKILL.md`, triggered
   before raising a PR. It writes the per-PR entry at
   `site/content/changes/<branch-slug>.md` from the branch's commits
   and trailer chain, and, when a summary is due by the CI check's
   rule, writes the summary for the period from the entries and the
   upcoming-work adapter. It can also be invoked manually to produce a
   summary. It applies the public content rules: no named people,
   internal events only where they publicised the project, no secrets.
   Eval scenarios, each with an assertion: a branch with a named author
   in its commits (the entry contains no author name); a due summary
   (the file `site/content/summaries/<%G>-W<%V>.md` exists with the
   required front matter).

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

10. **Update skill.** Author `skills/site-update/SKILL.md`, which
    compares the overview, long-form docs and reference docs with what
    exists in the project and proposes edits to bring them into line.
    Eval scenario: a doc describing a removed feature (the proposal
    edits or removes the passage naming that feature).

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

11. **Optional Claude Code hook.** Add a hook configuration that runs
    the writing skill before a PR is raised. It is optional, and CI
    remains the enforcement. Only Claude Code is supported.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

12. **Tessl tile and opt-in.** Package the skills, scripts, CI
    workflow, Pages workflow and hook configuration as a tessl tile,
    published to the tessl registry. Opt-in is `tessl install` of the
    tile plus the init script, which creates `site/` with
    `project.yaml` for the project's content type, installs the two
    workflows, offers the hook behind an opt-in flag, and is safe to
    re-run. The init script does not migrate existing weeknotes; the
    first summary is written by the writing skill from the git graph.
    Later updates arrive through tessl versioning. Tests run the init
    script on a fixture project twice, with and without the hook flag.

13. **Pilot.** Opt in this repository and one other myelin project the
    maintainer chooses, on GitHub. Raise a PR in each and confirm: the
    check fails without an entry, passes with one, the Pages deploy
    publishes, and the first summary is produced and passes the check.

14. **Completion.** Delete this plan in the final commit with the
    `Completes:` trailer and a body saying what the plan produced.

## Verification

- All unit tests pass in CI on this repository through the test
  workflow.
- On a test repository, a fixture built by the tests with the Pages
  workflow: a PR with no per-PR entry fails the check; adding the entry
  passes it; on a Thursday or later a PR with no summary for the week
  fails until one is added; merging deploys a site that shows overview,
  the sections its content type enables, per-PR entries, a summary, and
  upcoming items from GitHub issues.
- Replacing the upcoming-work source with the stub changes the
  upcoming list without any core change.
- A script over the built site, for verification only and not CI
  enforcement, finds none of the repository's git author names or
  common secret patterns.
- `tessl install` of the tile plus the init script opts a fixture
  project in.

## Progress notes

None yet.
