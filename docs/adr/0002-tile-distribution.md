---
title: How should an opted-in project's CI get the proj-site tile, whatever tessl mode the project uses?
date: 2026-11-25
---

# How should an opted-in project's CI get the proj-site tile, whatever tessl mode the project uses?

> **Directive for the implementer**: when implementing this ADR, invoke the `plans` skill to produce the corresponding plan artifact. Do not begin implementation without a plan.

## Context

ADR 0001 says only that proj-site is distributed "To opted-in projects as skills plus scripts". It says nothing about plugin visibility, tessl mode or how CI gets the tile.

Vendored mode (tessl's committed `.tessl/plugins/`) was added during plan 0001 step 12 only because of how CI finds the tile: both workflow templates set `SITE_TILE: .tessl/plugins/mhclg-aaai/proj-site` and run scripts from that path. In managed mode `.tessl/plugins/` is gitignored, so CI would fail with "file not found". The local pieces (`site-init.sh`, the optional hook) work in either mode.

Myelin, the second project in the plan 0001 step 13 pilot, rejected vendored mode because it goes against its core principles. That blocks the pilot.

Tests with an empty HOME, no `TESSL_*` variables, `@tessl/cli@0.123.0` and a throwaway managed-mode repo:
- An anonymous install of proj-site failed ("1 plugin may require authentication"). The plugin's visibility is Private, set by `"private": true` in `tile/.tessl-plugin/plugin.json`.
- An anonymous install of a public plugin worked.
- The failed install still exited 0.

A CI runner holds only GitHub's `GITHUB_TOKEN`. tessl and GitHub accounts are separate, so the pusher's membership of the private tessl workspace does not help. For the `tessl install` route the choice is a public plugin or a tessl key stored as a secret in every project. A direct trust route (tessl trusting GitHub Actions runs) was not ruled out.

Making the plugin public leaks nothing from projects: information flows one way, the tile's contents are generic, its fixtures are made up, and the source repo is already public.

## Decision

**CI route.** CI installs only the proj-site tile, in a temporary folder, from a one-dependency `tessl.json` pinned to the version the project's `tessl.json` lists, and points the site build there. It never installs the project's other dependencies. When the project pins proj-site to a local path, CI uses that folder directly. When the project does not list proj-site, CI fails with a clear message.

**Public plugin.** The proj-site plugin is public on the tessl registry, so an anonymous install works.

**No tessl-mode requirement.** proj-site works in any tessl mode and requires none.

## Alternatives considered

- **Install from the project's committed `tessl.json`** (this ADR's first route; reversed). It downloads every public dependency on every PR and deploy, relies on tessl skipping private ones with a warning, which tessl could change, and runs code the job does not need while a GitHub token is present.
- **Named install in the project** (`tessl install` of proj-site at its pinned version). Not chosen: simpler, but it still reads the project's other dependencies and rewrites the formatting of `tessl.json`.
- **Require vendored mode.** Rejected: it conflicts with myelin's principles, and proj-site should not be opinionated about tessl mode.
- **Keep the plugin private and store a tessl API key as a CI secret.** Not chosen: every opted-in project would need the secret, keys expire after 30 days unless set otherwise, and it adds an upkeep job. Which of `TESSL_TOKEN` or `TESSL_API_TOKEN` the CLI reads was not confirmed.
- **Check the tile out of the proj-site repo by tag.** Not chosen: proj-site has no release tags, every release would need one, and installs pinned to a commit would need separate handling.
- **Reusable workflows hosted in proj-site.** Not chosen: the version would be pinned in two places (`tessl.json` and the `uses:` ref), which could drift apart.
- **Rely on the pusher's tessl workspace membership.** Ruled out: the CI runner never acts as that person in tessl.

## Consequences

- Any project can opt in whatever its tessl mode, which unblocks the myelin pilot.
- Everything published under `tile/` is public, so its content needs checking.
- CI needs network access to the tessl registry and installs the CLI on each run.
- Left to the plan: how proj-site stops depending on vendored mode, including how the templates locate the tile; how CI responds to a failed install, which exits 0; whether to set `TESSL_SHARE_USAGE_DATA` in CI (unconfirmed that it works).
- Out of scope: private repos opting in and the timeline and upcoming pages publishing unreviewed titles (#23); a guard against sensitive text in issues (#24); which issues count as "coming next" (#21); per-project theming (#22); whether tessl can trust GitHub Actions runs without a stored secret; what the CLI's usage data actually sends, which happens whether the plugin is public or private.

## References

- ADR 0001: its "Distribution" decision (skills plus scripts) is the one this ADR specifies the CI route for; its enforcement check and Pages deploy are the CI workflows that need the tile.
