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
   - `site/content/changes/<YYYY-MM-DD>-<branch-slug>.md`, one per PR,
     dated with the UTC day the entry is written (on a collision the
     skill appends a numeric suffix), with front matter `title`,
     `date`, `theme`, `refs` (ADR, plan and issue references) and a
     plain-language body in the explored, decided, built, shipped
     order. At build time the core looks up the PR for the commit that
     added the entry with `gh`;
   - `site/content/summaries/<%G-W%V>.md` (for example `2026-W01.md`),
     named for the ISO week (UTC) containing the Thursday that starts
     the period, one per period, with front matter `period_start`,
     `period_end`, `counts`, and sections by theme, "Completed" and
     "In flight / queued" in the weeknotes style, listing PRs and
     issues by reference. A summary covers the period since the
     previous summary;
   - generated content is written at build time into an uncommitted
     build directory.

   Sections per content type: `knowledge` enables long-form docs;
   `code` enables reference docs; `both` enables both; overview,
   changes, summaries and upcoming are always enabled. The changes
   section also renders the full git-graph timeline (explored,
   decided, built, shipped), with work since the last summary marked
   as recent.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

3. **Core.** Write the scripts that build the site, in POSIX shell with
   git, `gh` and `jq`, plus the Hugo binary: read the git graph (ADRs,
   plans, `Derives-From`, `Revises`, `Consumed-By`, `Completes`,
   `Abandons` trailers) to produce the full timeline of done work, with
   work since the last summary marked as recent, merge in the per-PR entries and summaries, and
   generate Hugo content. Tests use a fixture git repository with a
   known trailer chain and assert the sections each content type
   enables and the expected timeline for that chain. Files: `tile/core/`
   and its tests.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

4. **Upcoming-work adapter.** Define the adapter interface: an executable
   the core calls, returning JSON on stdout, a list of items with
   title, reference, state, and theme. The theme comes from an issue
   label with a `theme:` prefix, empty when absent. Write the
   GitHub issues implementation behind it, run through `gh` and
   selected by `upcoming.source`. The core calls only the interface.
   Tests use a stub source and recorded `gh` output.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

5. **Reference-docs adapter.** Define and document the adapter
   interface (an executable the core calls, with the project path in
   and JSON on stdout carrying the Markdown or Hugo content) and write
   the first adapter, for Python (docstrings), which runs only in
   projects with Python code. Further languages follow
   as separate plans. Each adapter is enabled by the `languages`
   setting. Tests run the adapter on a small fixture module.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

6. **CI check script.** Write a script, in `tile/scripts/`, run on `pull_request`, with no
   agent involved. It fails the PR when:
   - the PR's diff adds no file under `site/content/changes/`;
   - a summary is due and missing. A summary is due when none has been
     produced since the most recent Thursday 00:00 UTC before the time
     the check runs: no file `site/content/summaries/<%G-W%V>.md`,
     named for the ISO week containing that Thursday, exists on the
     trunk, in the PR's diff, or in the diff of another open PR
     (queried with `gh`). No week is skipped; the next summary covers
     the period since the last one.

   Failure messages name the missing file and the skill that writes it.
   Tests assert: no entry fails; Thursday 2026-01-08 without a summary
   fails; Thursday with a summary on the trunk passes; Thursday with a
   summary in another open PR's diff passes; Wednesday 2026-01-07 with
   `2026-W01.md` on the trunk passes, and without it fails; Monday
   2026-01-12 with no `2026-W02.md` (no PR since Thursday 2026-01-08)
   fails until the PR adds `2026-W02.md`, then passes; summary added by
   the PR itself passes; runs at Sunday 2026-01-04 and Monday 2026-01-05
   both resolve to `2026-W01`; a run on Monday 2027-01-04 resolves to
   `2026-W53`.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

7. **Workflows.** Add templates, in `tile/templates/workflows/`, for two GitHub workflows: the
   `pull_request` workflow that runs the CI check, and the Pages
   workflow that builds with the core and deploys to GitHub Pages on
   merge to the trunk. Both check out with `fetch-depth: 0` and have
   `contents: read` and `pull-requests: read`; the Pages workflow also
   has `issues: read`, `pages: write` and `id-token: write`, and the opt-in documentation says to enable
   Pages for the repository. Verify both on this repository and the
   pilot (see Verification).

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

8. **Test workflow.** Add `.github/workflows/test.yml` for this
   repository, running `tests/run.sh`, which runs the unit tests of
   every step, on `pull_request` and on push to the trunk, with Python
   and Hugo installed in the workflow.

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

9. **Writing skill.** Author `tile/skills/site-writing/SKILL.md`, triggered
   before raising a PR. It writes the per-PR entry at
   `site/content/changes/<YYYY-MM-DD>-<branch-slug>.md` from the
   branch's commits and trailer chain, and, when a summary is due by
   the CI check's rule (using the current UTC time), writes the summary,
   named by that rule, for the period from the entries and the upcoming-work adapter. It
   can also be invoked manually to produce a summary; a second manual
   summary in a week updates the existing file. It applies the public
   content rules: no named people, internal events only where they
   publicised the project, no secrets. Eval scenarios, each with an assertion: a branch with a named author
   in its commits (the entry file exists with its required front
   matter, then contains no author name); a due summary
   (the file `site/content/summaries/<%G-W%V>.md` exists with the
   required front matter).

> **Directive for the implementer**: this step will author a new skill. Load the `skill-forge` skill before writing the `SKILL.md` (frontmatter → failing eval scenario → skill body).

10. **Update skill.** Author `tile/skills/site-update/SKILL.md`,
    triggered before raising a PR that changes code or docs, or on
    request. It edits the overview, long-form docs and docstrings so
    they match what exists in the project; the edits are reviewed in
    the PR. Eval scenario: a doc describing a removed feature (the
    edit removes or changes the passage naming that feature).

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

11. **Optional Claude Code hook.** Add a Claude Code `PreToolUse` hook
    on Bash matching `gh pr create` that blocks with an instruction to
    run the writing skill when the branch adds no entry. It is
    optional, and CI remains the enforcement. Only Claude Code is
    supported. Tests assert the hook blocks without an entry and
    passes with one.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

12. **Tessl tile and opt-in.** Package the skills, scripts, CI
    workflow, Pages workflow and hook configuration as a tessl tile,
    with all shipped files under `tile/` in this repository
    (`tile/core/`, `tile/skills/`, `tile/scripts/`,
    `tile/templates/workflows/`), published to the tessl registry as
    `mhclg-aaai/proj-site`. Before publishing, install from a local
    path to `tile/`; after, from the registry tile. Opt-in is
    `tessl install` of the tile plus `tile/scripts/site-init.sh`, which
    creates `site/` with `project.yaml` for the project's content type,
    installs the two workflows from `tile/templates/workflows/`, adds the hook only with
    `--with-claude-hook`, and on a second run makes no changes and
    preserves a hand-edited `project.yaml`. The init script does not
    migrate existing weeknotes; the first summary is written by the
    writing skill from the git graph.
    Later updates arrive through tessl versioning. Tests run the init
    script on a fixture project twice, with and without
    `--with-claude-hook`.

13. **Pilot.** Opt in this repository and one other myelin project the
    maintainer chooses, on GitHub. Raise the opt-in PR in each
    with its own entry and confirm: the check fails without an entry,
    passes with one, the Pages deploy publishes, and the first summary is produced
    and passes the check.

14. **Completion.** Delete this plan in the final commit with the
    `Completes:` trailer and a body saying what the plan produced.

## Verification

- All unit tests pass in CI on this repository through the test
  workflow.
- Local fixtures cover the script tests. The workflow-level checks
  run on this repository's own opt-in and on the pilot: a PR with no
  per-PR entry fails the check; adding the entry passes it; a
  PR with no summary produced since the most recent Thursday fails
  until one is added; merging deploys a site that shows overview, the sections
  its content type enables, per-PR entries, a summary, and upcoming
  items from GitHub issues.
- Replacing the upcoming-work source with the stub changes the
  upcoming list without any core change.
- `tests/scan-site.sh`, a script over the built site, for verification only and not CI
  enforcement, finds none of the repository's git author names or
  common secret patterns.
- `tessl install` of the tile plus the init script opts a fixture
  project in.

## Progress notes

None yet.
