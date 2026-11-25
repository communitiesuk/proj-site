# proj-site

Opt-in tooling that gives a myelin project an automatically maintained
public site on GitHub Pages. Decided in
[ADR 0001](docs/adr/0001-project-site.md).

The site has two audiences:

- **Users** of the project's outputs: a hand-written overview, hand-written
  long-form docs, and reference docs generated from docstrings.
- **Stakeholders**: a story of what was explored, decided, built and
  shipped, read from the git graph, plus a per-PR entry for every PR and a
  weekly summary.

## What ships

Everything a project installs lives under `tile/`, packaged as the tessl
tile `mhclg-aaai/proj-site`. The registry archive holds only the manifest and
`skills/`, so the runtime lives inside the `site-setup` skill
(`tile/skills/site-setup/`, written `S/` below):

| Path | What it is |
| --- | --- |
| `S/core/` | The build: bash 4+ with `git`, `gh` and `jq`, plus Hugo. |
| `S/adapters/upcoming/` | Upcoming-work adapters (`github-issues`, `stub`). |
| `S/adapters/reference/` | Reference-docs adapters, one per language (`python`). |
| `S/scripts/` | The PR check, the opt-in script and the Claude Code hook. |
| `tile/skills/` | `site-setup` (opt in, build), `site-writing` (entries and summaries) and `site-update` (keeps docs aligned). |
| `S/templates/workflows/` | The PR-check and Pages workflows an opted-in project installs. |

## What an opted-in project holds

```
site/
  project.yaml
  content/
    overview.md                         hand-written
    docs/                               hand-written long-form docs
    changes/<YYYY-MM-DD>-<branch-slug>.md   one per PR
    summaries/<%G-W%V>.md               one per weekly period
```

### `site/project.yaml`

A restricted YAML subset: `key: value`, inline lists `[a, b]`, and one level
of nesting.

```yaml
name: Example project
repository: communitiesuk/example
content_type: both          # knowledge | code | both
languages: [python]         # reference-docs adapters to run
upcoming:
  source: github-issues     # upcoming-work adapter to run
```

### Sections per content type

| Section | knowledge | code | both |
| --- | --- | --- | --- |
| Overview | yes | yes | yes |
| Changes (timeline and per-PR entries) | yes | yes | yes |
| Summaries | yes | yes | yes |
| Upcoming | yes | yes | yes |
| Docs (long-form) | yes | no | yes |
| Reference (generated) | no | yes | yes |

### Per-PR entries

`site/content/changes/<YYYY-MM-DD>-<branch-slug>.md`, dated with the UTC day
the entry is written. On a collision the writer appends `-2`, `-3`, ….

```markdown
---
title: Plain-language outcome of the PR
date: 2026-01-08
theme: Release assurance
refs: ["docs/adr/0001-example.md", "#42"]
---
Plain-language body in explored, decided, built, shipped order.
```

At build time the core adds `week` (`%G-W%V`) and, where GitHub can be
reached, `pr` (the PR that added the entry).

### Weekly summaries

`site/content/summaries/<%G-W%V>.md`, named for the ISO week (UTC) containing
the Thursday that starts the period. A summary covers the period since the
previous summary.

```markdown
---
title: Week of 2026-01-08
period_start: 2026-01-01
period_end: 2026-01-08
counts: {prs: 6, issues_closed: 3}
---
## <Theme>
- Outcome in plain language (#123)

## Completed
- …

## In flight / queued
- …
```

A summary is **due** when no summary exists for the ISO week containing the
most recent Thursday 00:00 UTC. No week is skipped.

### Public content rules

Everything under `site/` is public. No named people. Internal events only
where they publicised the project (show and tells, talks). No secrets.

## Contracts

### Upcoming-work adapter

A script at `S/adapters/upcoming/<source>.sh` (run with `bash`) or
`<source>.py` (run with `python3`), selected by `upcoming.source`.

- Invoked as `<adapter> <project-dir>`, with the working directory set to
  the project.
- Writes to stdout a JSON array of items:
  `{"title": str, "ref": str, "state": str, "theme": str}`. `theme` is the
  issue label with a `theme:` prefix, prefix removed, or `""`.
- Exits non-zero, with a message on stderr, when it cannot read its source.

### Reference-docs adapter

A script at `S/adapters/reference/<language>.sh` or `<language>.py`,
enabled by `languages`.

- Invoked as `<adapter> <project-dir>`.
- Writes to stdout a JSON array of pages:
  `{"path": str, "title": str, "content": str}`, where `path` is relative
  to the reference section (for example `pkg/module.md`) and `content` is
  Markdown.
- Writes `[]` when the project has no source in that language.

### PR check

`S/scripts/check-pr.sh`, run by the PR-check workflow with no agent.
It fails the PR when the PR adds no file under `site/content/changes/`, or
when a summary is due and is not on the trunk, in the PR's diff, or in
another open PR's diff. Failure messages name the missing file and the
skill that writes it.

### Build

`S/core/build.sh <project-dir> <out-dir>` assembles a Hugo source tree in
`<out-dir>/src` (uncommitted) and renders the site into `<out-dir>/public`.

## Packaging

The tessl registry delivers only files ending in `.md`, `.txt`, `.json`,
`.yml`, `.yaml`, `.toml`, `.sh`, `.py`, `.js`, `.ts`, `.tsx` or `.jsx`, and drops
the executable bit. So every script is run as `bash <path>` or
`python3 <path>`, Hugo layouts ship as `*.html.txt`, renamed by the build, and
the workflow templates ship as `*.yml.txt`, renamed by `site-init.sh`: a
registry install of 0.1.0 delivered no `*.yml` file.

## Opting in

Any tessl mode works. The site workflows install the tile themselves: each
run installs the pinned tessl CLI with `npx`, runs `tessl install` from the
project's committed `tessl.json`, and fails the job if the tile did not arrive
at `.tessl/plugins/mhclg-aaai/proj-site/`. So CI needs network access to the
tessl registry. A private dependency in `tessl.json` is skipped in CI with a
warning; the workflows need only proj-site, which is public.

```sh
tessl install mhclg-aaai/proj-site
bash .tessl/plugins/mhclg-aaai/proj-site/skills/site-setup/scripts/site-init.sh [--content-type knowledge|code|both] [--trunk <branch>] [--with-claude-hook]
```

Then enable GitHub Pages for the repository with "GitHub Actions" as the
source, and raise the opt-in PR with its own per-PR entry.

## Development

```sh
tests/run.sh          # runs every tests/test_*.sh
```
