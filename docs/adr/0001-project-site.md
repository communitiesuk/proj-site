---
title: How should myelin projects get an automatically maintained public project site?
date: 2026-11-23
---

# How should myelin projects get an automatically maintained public project site?

> **Directive for the implementer**: when implementing this ADR, invoke the `plans` skill to produce the corresponding plan artifact. Do not begin implementation without a plan.

## Context

Each myelin project (communitiesuk/myelin) should have a GitHub Pages site for two audiences: users of the project's outputs (knowledge, code, or both), and stakeholders who want to know what has been done, what was recently completed, and what is coming up.

Nothing publishes user-facing material today. The stakeholder story exists only as weeknotes in `../myelin/weeknotes`, which is gitignored in myelin, deliberately. The weeknotes are the model for tone and shape: plain-language outcomes grouped by theme with PR and issue references, a "Completed" section, an "In flight / queued" section, and a period with counts. History lives in the git graph (ADRs, plans, and trailers such as `Derives-From` and `Consumed-By`). Upcoming work is tracked in GitHub issues for now.

## Decision

**Location.** The site tooling is a separate project, this repo (`proj-site`), not part of myelin. Myelin projects opt into it.

**Architecture.** A core plus adapters.
- The core handles site structure, rendering, and reading the git graph.
- Adapters supply upcoming work (GitHub issues today, behind a swappable source: the site does not integrate with GitHub issues directly) and reference docs (one docstring extractor per language; the site is language independent).
- A project's content type (knowledge, code, or both) decides which site sections appear.

**User-facing content.** A mix: a hand-written "what is this project" overview, hand-written long-form docs, and reference docs derived from code docstrings. An update skill keeps all of these, long-form included, aligned with what exists.

**Stakeholder content.** A narrative story following myelin's trailer chain: explored, decided, built, shipped. It has two parts:
- a per-PR entry for each PR;
- a periodic summary in the weeknotes style (plain-language outcomes by theme, PR and issue references, completed and upcoming).

The weeknotes are not republished. The site has its own public story.

**Summary cadence.** The periodic summary can be triggered manually. It is also due automatically weekly: at the first PR on a Thursday, or the next PR after that, provided none has been produced in the same week.

**Public content rules.** No named people. Internal events are mentioned only where they publicised the project (show and tells, talks). No secrets.

**Writing and enforcement are separate.**
- Writing is done by a skill triggered before raising a PR. Skills are cross-agent through tessl.
- Enforcement is a CI check on `pull_request`, with no agent involved. A script fails the PR if the per-PR entry is missing, or if the weekly summary is due and missing.
- A Claude Code hook may run the skill as an optional speed-up only. Claude-only support for it is acceptable at first.

**Deploy.** The site is deployed to GitHub Pages by a GitHub workflow.

**Distribution.** To opted-in projects as skills plus scripts.

**Generator.** Hugo is the generator to try, not a settled choice; a short spike early in the plan confirms or replaces it.

## Alternatives considered

- **Build it into myelin.** Rejected: the site is a separate project that myelin projects opt into.
- **Wire GitHub issues directly into the site.** Rejected: the upcoming-work source may change, so it sits behind an adapter.
- **Republish the weeknotes.** Rejected: they are deliberately private.
- **A rolling "recently" page rewritten on every PR, or per-PR entries grouped only at build time with no periodic summary.** Rejected in favour of per-PR entries plus a periodic summary: parallel PRs would conflict on a shared page.
- **A harness-specific hook alone, or git hooks alone.** Rejected in favour of the skill-plus-CI split. Git hooks are agent-neutral but cannot write prose without calling a specific agent's CLI.
- **Hand-written-only or fully derived user content.** Rejected in favour of the mix above.
- **Other generators.** Quarto (heavier install, data-science lean), MkDocs Material or Zensical (Python-centred; the state of MkDocs 1.x versus Zensical is unverified), Astro Starlight (adds Node and a JavaScript toolchain to every opted-in project) and Jekyll (Ruby, aging ecosystem, weak collections) were not chosen. Hugo is a single binary with no language runtime and strong content types, taxonomies and data files; its downside is Go templating.

## Consequences

- Opting in costs a project the installed skills and scripts, a CI check, and a Pages workflow.
- Because the CI check only enforces that the summary exists, the summary is written by an agent running the skill, not by CI.
- Every PR on an opted-in project carries a per-PR entry.
- Left open: the Hugo spike's outcome; the specific language adapters and which sections each content type enables; support beyond Claude Code for the hook; where an agent would run if summaries were ever produced in CI.

## References

- ADR-less upstream: myelin's trailer chain (`Derives-From`, `Consumed-By`) is read by the core to build the story.
- `../myelin/weeknotes` (private): the model for the periodic summary's shape.
