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

1. **Spike: how a managed-mode CI run gets the tile.** In a throwaway
   managed-mode repo (scratch directory, empty HOME, no `TESSL_*`
   variables), with the CLI version the workflows will pin (start from
   `@tessl/cli@0.123.0`), settle and record in Progress notes:
   - where `tessl install` puts the tile, and whether that is the path
     the templates' `SITE_TILE` can name for every tessl mode;
   - the check that detects a failed install, which exits 0 (for
     example, the tile's `skills/site-setup/SKILL.md` is absent);
   - that a version in the project's `tessl.json` is the one installed;
   - whether `TESSL_SHARE_USAGE_DATA` is honoured. If it cannot be
     confirmed, the templates do not set it.

   The spike installs the tile from a local path until step 4 makes the
   plugin public; its anonymous-install result is rechecked in step 5.
   Commit: the notes only; the scratch repo is discarded.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

2. **Workflow templates install the tile.** In
   `tile/skills/site-setup/templates/workflows/site-check.yml.txt` and
   `site-pages.yml.txt`, before the step that runs the tile, add steps
   that install the pinned tessl CLI, run `tessl install` from the
   project's committed `tessl.json`, and fail the job with a message
   naming the missing tile when the spike's check finds the install
   failed. Set `SITE_TILE` to the spike's path. Change
   `tests/test_workflows.sh` first: assert both templates install the
   CLI, run `tessl install`, run the failed-install check before the
   script that uses the tile, and that every `$SITE_TILE/...` path
   still exists in the tile. The check workflow keeps its read-only
   permissions.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

3. **Opt-in no longer requires vendored mode.** In
   `tile/skills/site-setup/scripts/site-init.sh`, remove the
   not-vendored warning and its header comment; change
   `tests/test_init.sh` first, replacing
   `test_init_warns_without_vendored_mode_and_requires_repo_root`'s
   warning assertion with one that a managed-mode `tessl.json` produces
   no warning and the same files, keeping the repo-root assertions. In
   the same commit, give the opt-in fixture in
   `tile/evals/site-setup-0/setup.sh` a managed-mode `tessl.json` and
   update `criteria.json` (its context line and the workflow-path
   criterion) to the templates' new content.

4. **Docs match.** Edit `tile/skills/site-setup/SKILL.md` (prerequisites
   step 1: drop the vendored requirement and the ask-before-changing
   rule; leave the frontmatter `description` unchanged) and `README.md`
   ("Opting in", and "Packaging" if it names the vendored path). Add to
   the README that CI needs network access to the tessl registry and
   installs the CLI on each run. Regenerate this repository's
   `.github/workflows/site-check.yml` and `site-pages.yml` from the
   templates (the template changes of step 2, with `__TRUNK__` set to
   `dev`).

5. **Public plugin.** Remove `"private": true` from
   `tile/.tessl-plugin/plugin.json` and bump `version` (minor). Add a
   test to `tests/test_packaging.sh` asserting the manifest has no
   `private: true`. Audit everything under `tile/` for text that must not
   be public (names, internal URLs, secrets, private fixtures) and record
   the result in Progress notes. Commit: the manifest, the test and any
   fixes.

6. **Publish and verify anonymously.** After the branch lands on the
   trunk, publish the tile to the registry (the maintainer, with
   `tessl` credentials) and confirm its visibility is Public. Then, in a
   fresh managed-mode throwaway repo with an empty HOME and no `TESSL_*`
   variables, pinned to the published version in `tessl.json`: run
   `tessl install`, check the tile is present, and run `site-init.sh`.
   Record the result in Progress notes. If the install fails, stop and
   report.

7. **Pilot on myelin.** Opt myelin in (managed mode) with the opt-in PR
   and its own entry, and confirm in GitHub Actions: the check workflow
   installs the tile and fails without an entry and passes with one; the
   Pages workflow builds and deploys. This closes the myelin half of
   plan 0001 step 13.

8. **Completion.** Delete this plan in the final commit with the
   `Completes:` trailer and a body saying what the plan produced.

## Verification

- `tests/run.sh` passes in CI, including the new template, init and
  packaging assertions.
- A managed-mode fixture repo with an empty HOME installs the published
  tile anonymously and runs `site-init.sh` without a vendored-mode
  warning.
- On myelin, a managed-mode repo with `.tessl/plugins/` gitignored:
  the check workflow passes and fails as above, and the Pages deploy
  publishes.
- This repository's regenerated workflows run green on a PR.
- A deliberately failed install (for example a nonexistent plugin
  version in `tessl.json`) fails the workflow job with the missing-tile
  message, not a later "file not found".

## Progress notes
