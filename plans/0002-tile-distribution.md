---
title: Distribute the proj-site tile to CI in any tessl mode
status: draft
adr: 0002
date: 2026-11-25
deferred_reason: null
---

# Distribute the proj-site tile to CI in any tessl mode

Implements [ADR 0002](../docs/adr/0002-tile-distribution.md). Unblocks the
myelin pilot, step 13 of [plan 0001](0001-project-site.md).

## Steps

Steps 1 to 4 land on one implementation branch. Steps 5 and 6 need the
published tile and the pilot, so their results and the plan's deletion (step
7) land on a second, final implementation branch. Each commit that changes
`tile/` also runs `tessl install`, refreshing this repository's vendored
`.tessl/plugins/mhclg-aaai/proj-site`.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

1. **Workflow templates install the tile.** `SITE_TILE` and the
   `$SITE_TILE/...` paths stay. In
   `tile/skills/site-setup/templates/workflows/site-check.yml.txt` and
   `site-pages.yml.txt`, before the step that runs the tile, add:
   - an install step, `npx -y @tessl/cli@0.123.0 install --yes --accept-warnings`,
     run from the project's committed `tessl.json`;
   - a check step that fails the job, with a message naming the missing
     tile and `tessl.json`, unless
     `"$SITE_TILE/skills/site-setup/scripts/check-pr.sh"` exists.

   In `site-check.yml.txt`, move `SITE_TILE` from the check step's `env` to
   the job's `env` (as `site-pages.yml.txt` already has it), so the new
   check step sees it.

   Change `tests/test_workflows.sh` first: assert both templates set
   `SITE_TILE` at job level, run the pinned CLI version, run the install, and
   run the check before the script that uses the tile.
   `test_templates_reference_scripts_that_exist_in_the_tile` stays unchanged.
   The templates do not set `TESSL_SHARE_USAGE_DATA`. The check workflow keeps its read-only
   permissions.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

2. **Opt-in no longer requires vendored mode.** In
   `tile/skills/site-setup/scripts/site-init.sh`, remove the
   not-vendored warning and its header comment. Change
   `tests/test_init.sh` first: rename
   `test_init_warns_without_vendored_mode_and_requires_repo_root` to
   `test_init_requires_repo_root_and_accepts_managed_mode`, replace its
   warning assertion with one that a `tessl.json` with `"mode": "managed"`
   produces no warning and creates `site/project.yaml`, `site/content/overview.md`,
   `.github/workflows/site-check.yml` and `.github/workflows/site-pages.yml`,
   and keep the repo-root assertions. In the same commit, give the opt-in
   fixture in `tile/evals/site-setup-0/setup.sh` a `tessl.json` with
   `"mode": "managed"` (change its header comment too). In `criteria.json`,
   change the context line's `tessl.json` to `"mode": "managed"`, and extend
   the workflows criterion: both workflows run
   `npx -y @tessl/cli@0.123.0 install` and test that
   `$SITE_TILE/skills/site-setup/scripts/check-pr.sh` exists, and
   `tessl.json` keeps `"mode": "managed"`.

3. **Docs match.** Edit `tile/skills/site-setup/SKILL.md` (prerequisites
   step 1: drop the vendored requirement and the ask-before-changing
   rule; leave the frontmatter `description` unchanged) and `README.md`
   ("Opting in") and `site/content/docs/opting-in.md` (its Requirements
   bullet that requires vendored mode). Other references to the local install path stay. Add to
   the README that CI needs network access to the tessl registry, installs
   the CLI on each run, and skips private dependencies with a warning.
   Regenerate this repository's `.github/workflows/site-check.yml` and
   `site-pages.yml` from the templates (the template changes of step 1,
   with `__TRUNK__` set to `dev`). This repository's `tessl.json` stays
   vendored with its `file:tile` source.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

4. **Public plugin.** Remove `"private": true` from
   `tile/.tessl-plugin/plugin.json` and bump `version` to `0.2.0`. Add a
   test to `tests/test_packaging.sh` first, asserting the manifest has no
   `private: true`. Audit everything under `tile/` for text that must not
   be public (names, internal URLs, secrets, private fixtures) and record
   the result in Progress notes. Commit: the manifest, the test and any
   fixes.

5. **Publish and verify anonymously.** After the first implementation
   branch lands on the trunk (`dev`), the maintainer publishes from their local
   login with `tessl plugin publish tile` and confirms with
   `tessl plugin info mhclg-aaai/proj-site` that the visibility is Public. Then, in fresh managed-mode throwaway repos with an empty HOME
   and no `TESSL_*` variables:
   - pin `0.2.0` in `tessl.json`, run `tessl install`, and assert the tile
     is at `.tessl/plugins/mhclg-aaai/proj-site` (`SITE_TILE`), its
     manifest version is `0.2.0`, and `site-init.sh` creates
     `site/project.yaml`, `site/content/overview.md` and the two workflows;
   - pin a nonexistent version, run the install and the templates' check,
     and assert the check fails with the missing-tile message.

   Record both results in Progress notes on the second implementation
   branch. If the 0.2.0 install fails, stop and report.

6. **Hand back to plan 0001.** Plan 0001 step 13 runs the myelin pilot
   (opt-in PR with its own entry; the check workflow installs the tile and
   fails without an entry and passes with one; Pages builds and
   deploys). Record the myelin outcome in plan 0001's Progress notes, on the
   second implementation branch.

7. **Completion.** Delete this plan in the final commit of the second
   implementation branch, with the `Completes:` trailer and a body saying what the plan produced.

## Verification

- `tests/run.sh` passes in CI, including the new template, init and
  packaging assertions.
- A managed-mode fixture repo with an empty HOME installs the published
  `0.2.0` tile anonymously at `SITE_TILE`, and `site-init.sh` creates
  `site/project.yaml`, `site/content/overview.md` and the two workflows.
- This repository's regenerated workflows run green on a PR.
- A managed-mode throwaway repo pinned to a nonexistent plugin version
  fails the template's check with the missing-tile message, not a later
  "file not found"; the result is in Progress notes (step 5).
- On myelin, a managed-mode repo with `.tessl/plugins/` gitignored: the
  check workflow passes and fails as above, and the Pages deploy
  publishes (plan 0001 step 13).

## Progress notes
