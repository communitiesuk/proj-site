---
title: Install only the proj-site tile in CI, from a temporary folder
status: in-progress
adr: 0002
date: 2026-11-26
deferred_reason: null
---

# Install only the proj-site tile in CI, from a temporary folder

Implements [ADR 0002](../docs/adr/0002-tile-distribution.md) as revised in
PR #35 (the CI route). Replaces the remaining steps of
plan 0002, whose workflow templates installed
from the project's committed `tessl.json`: plan 0002 is abandoned on this
plan's own branch, and its anonymous install check is replaced by step 6. The
myelin pilot stays with [plan 0001](0001-project-site.md) step 13.

## Steps

Paths under `S/` mean `tile/skills/site-setup/`. Steps 1 to 5 land on one
implementation branch. The maintainer publishes from the trunk (step 6), and
the rest of step 6 and steps 7 and 8 land on a final branch. Each commit that
changes `tile/` also runs `tessl install`, refreshing this repository's
vendored `.tessl/plugins/mhclg-aaai/proj-site`.

Both templates carry the same step, word for word.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

1. **Workflow templates locate the tile.** In
   `S/templates/workflows/site-check.yml.txt` and `site-pages.yml.txt`,
   remove `SITE_TILE` from the job `env` and replace the "Install the
   proj-site tile" and "Check the tile was installed" steps with one step,
   "Locate the proj-site tile", before the step that uses the tile. Its `run`
   script (bash, using `jq`) does the following, from the workspace root:
   - Fails with an `::error::` message saying that `tessl.json` is missing
     or does not list `mhclg-aaai/proj-site`, when either is the case.
   - Fails with a message naming `mhclg-aaai/proj-site` and the missing pin
     when the dependency has neither a `file:` source nor a `version`.
   - When the dependency has a `source` of the form `file:<path>`, sets
     `SITE_TILE` to `<path>` and installs nothing.
   - Otherwise takes the dependency's `version`, makes a folder under
     `$RUNNER_TEMP`, writes into it a `tessl.json` whose only dependency is
     `mhclg-aaai/proj-site` at that version, runs
     `npx -y @tessl/cli@0.123.0 install --yes --accept-warnings` with that
     folder as the working directory, and sets `SITE_TILE` to
     `<folder>/.tessl/plugins/mhclg-aaai/proj-site`.
   - Fails, with a message naming the missing tile and `tessl.json` (and,
     on the registry route, the version), when the install exits non-zero
     or `"$SITE_TILE/skills/site-setup/scripts/check-pr.sh"` does not exist
     (a skipped install exits 0).
   - Appends `SITE_TILE=<value>` to `$GITHUB_ENV`, so the later steps keep
     using `$SITE_TILE`.

   Update both templates' header comments to say this. The templates do not
   set `TESSL_SHARE_USAGE_DATA`. The check workflow keeps its read-only
   permissions.

   Change `tests/test_workflows.sh` first. Replace
   `test_templates_set_site_tile_for_the_whole_job` and
   `test_templates_install_the_tile_and_check_it_before_use`, and drop the
   `SITE_TILE: .tessl/...` assertion in
   `test_templates_reference_scripts_that_exist_in_the_tile`
   (the `$SITE_TILE/...` script-existence check stays). Update the file's
   header comment, and remove `TESSL_INSTALL`, `TILE_CHECK` and (unless the
   new order test uses it) `line_of`. New tests assert, for each template: no
   `SITE_TILE:` line under `env`; the "Locate the proj-site tile" step runs
   before the first `bash "$SITE_TILE/` line; the step's `run` text is
   identical in both templates; no `TESSL_SHARE_USAGE_DATA`. Behavioural
   tests extract the step's `run` script with `awk`, run it with
   `bash -e`, as Actions does, in a fixture workspace with a stub `npx` first
   on `PATH` (logging each call, its arguments and working directory, and
   creating, or not, the tile at `.tessl/plugins/mhclg-aaai/proj-site` in its
   working directory, with `skills/site-setup/scripts/check-pr.sh` under it),
   and `RUNNER_TEMP` and `GITHUB_ENV` set to fixture paths outside the
   workspace:
   - `tessl.json` pinning `0.3.0` alongside another dependency: the stub ran
     once, in a folder under `RUNNER_TEMP`, whose `tessl.json` lists only
     proj-site at `0.3.0`; the logged arguments are
     `-y @tessl/cli@0.123.0 install --yes --accept-warnings`; the workspace `tessl.json` is byte-identical;
     `GITHUB_ENV` names the temp tile.
   - `"source": "file:tile"`, the fixture having
     `tile/skills/site-setup/scripts/check-pr.sh`: exit 0, the stub's log is
     empty and nothing was created under `RUNNER_TEMP`; `GITHUB_ENV` has
     `SITE_TILE=tile`.
   - `tessl.json` without proj-site: exit non-zero, the message names
     `mhclg-aaai/proj-site` and `tessl.json`, the stub's log is empty.
   - no `tessl.json`: the same.
   - proj-site listed with neither `source` nor `version`: exit non-zero, the
     message names the missing pin, the stub's log is empty.
   - the stub exits 0 without creating the tile, or exits non-zero: exit
     non-zero, the message names the missing tile.

   Commit: the templates and the tests.

2. **Opt-in script and evals match.** `S/scripts/site-init.sh` copies the
   templates unchanged, so only its header comment changes: replace "the
   workflows install the tile themselves" with a sentence that they locate
   the tile from `tessl.json` and install only proj-site. In `tile/evals/site-setup-0/criteria.json`,
   replace the "Both workflows, with the trunk substituted" criterion's
   `description` with:

   > `.github/workflows/site-check.yml` and `.github/workflows/site-pages.yml`
   > are committed on `dev`; the Pages workflow contains `branches: [dev]` and
   > no `__TRUNK__`; both have a "Locate the proj-site tile" step that reads
   > `mhclg-aaai/proj-site` from `tessl.json`, installs only that dependency in
   > a temporary folder, and tests that
   > `$SITE_TILE/skills/site-setup/scripts/check-pr.sh` exists; `git show
   > dev:tessl.json` keeps `"mode": "managed"`. FAILS IF: either workflow is
   > missing, the trunk is wrong or unsubstituted, a workflow lacks the step,
   > installs the project's other dependencies or skips the tile check, or
   > `tessl.json` was switched out of managed mode.

   Leave
   `setup.sh` as it is. Commit: the script comment and `criteria.json`.

3. **This repository's workflows.** `tessl.json` stays vendored, with
   `mhclg-aaai/proj-site` sourced from `file:tile`. Regenerate the two
   workflows from the templates:

   ```sh
   rm .github/workflows/site-check.yml .github/workflows/site-pages.yml
   bash tile/skills/site-setup/scripts/site-init.sh --trunk dev
   ```

   Confirm `git status` shows only those two workflows changed, and that
   each `git diff` shows only the template changes of step 1. Commit: the two
   workflows.

4. **Docs match.** Edit:
   - `README.md`, "Opting in": replace the paragraph from "Any tessl mode
     works" to "which is public" with: any tessl mode works; each run reads
     the proj-site entry in the project's committed `tessl.json`, uses a
     `file:` source as it stands, or else installs only proj-site at the
     listed version into a temporary folder with the pinned CLI, never the
     project's other dependencies; the job fails with a message when
     proj-site is not usable (not listed in `tessl.json`, or listed with no
     `file:` source or version) or the tile did not arrive; CI
     needs network access to the tessl registry unless proj-site is pinned to
     a local path. Add a paragraph, "Projects already opted in": `site-init.sh`
     never overwrites existing files, so such a project deletes
     `.github/workflows/site-check.yml` and `site-pages.yml` and re-runs
     `site-init.sh` (with `--trunk <branch>` when the trunk is not found),
     then reviews the diff for local edits, then commits the two workflows.
   - `site/content/guides/opting-in.md`: the Requirements bullet (the same
     CI facts, shorter) and a closing section, "If the project is already
     opted in", with the same instructions.
   - `tile/skills/site-setup/SKILL.md`: prerequisites step 1, replacing "the
     workflows install the tile themselves" with the same CI facts in one
     sentence, and a bullet under the opt-in script's behaviour step saying
     that a project opted in earlier regenerates its workflows by deleting the
     two files first. The frontmatter `description` stays unchanged.

   `site/content/docs/how-it-works.md` does not describe how CI gets the
   tile; confirm with `grep -n "tessl" site/content/docs/how-it-works.md` and
   leave it. Then run `site-update` over the changed docs. Commit: the docs.

5. **Version and entry.** Bump `version` in `tile/.tessl-plugin/plugin.json`
   to `0.4.0` and run `tessl install` to refresh the vendored copy. Write
   this change's per-PR entry (`site-writing`) at
   `site/content/changes/<date>-plan-0004-tile-install.md`, dated the day it
   is written, before the PR is opened. Commit: manifest, vendored refresh, entry.

6. **Publish and verify.** After the implementation branch lands on the
   trunk (`dev`), the maintainer publishes from their local login with
   `tessl plugin publish tile` and confirms with
   `tessl plugin info mhclg-aaai/proj-site` that `0.4.0` is listed and the
   visibility is Public. Then, in throwaway managed-mode repos with an empty
   HOME and no `TESSL_*` variables, run the "Locate the proj-site tile"
   script extracted from the trunk's `site-check.yml.txt`, with `RUNNER_TEMP`
   and `GITHUB_ENV` set to fixture paths outside the repo and the real `npx`:
   - `tessl.json` pinning `0.4.0` and `mhclg-aaai/myelin` as the other
     dependency: the script exits 0; its output never mentions myelin; the
     temporary folder's `.tessl/plugins/` holds only `mhclg-aaai/proj-site`;
     its manifest `version` is `0.4.0`; the workspace has no new `.tessl/`
     folder and its `tessl.json` is byte-identical; `GITHUB_ENV` names the
     tile; running `site-init.sh --content-type knowledge` and, after
     setting `upcoming.source: stub` in `site/project.yaml`,
     `bash "$SITE_TILE/skills/site-setup/core/build.sh" . out` in the repo produce
     `site/project.yaml` and a built `out/public/`.
   - `"source": "file:<folder>"` pointing at a copy of the tile: exit 0,
     `npx` is not invoked (a logging wrapper first on `PATH` stays empty),
     nothing is created under `RUNNER_TEMP`, `SITE_TILE` is that folder.
   - a nonexistent version: exits non-zero with the missing-tile message.
   - proj-site not listed: exits non-zero with the not-listed message.

   Record the four results in Progress notes on the final branch. If the
   `0.4.0` install fails, stop and report.

7. **Projects already opted in.** Every other project opted in with the
   0.2.0 or 0.3.0 templates, whose workflows still run `tessl install`,
   regenerates its workflows as step 4's README paragraph says, in a PR with
   its own entry; the myelin pilot stays with plan 0001 step 13. On this
   repository (regenerated in step 3), the workflows run green on a PR
   (Actions) and its Pages deploy publishes after merge. On each other such project, record in Progress notes whether
   its check workflow now passes and fails as the site-check expects
   (without an entry, with one), and its Pages deploy publishes. If a
   project cannot be reached, or there is none, record that and why.

8. **Completion.** Delete this plan in the final commit of the final branch,
   after steps 6 and 7's records are committed, with the `Completes:` trailer
   and a body saying what the plan produced.

## Verification

- `tests/run.sh` passes in CI, including the new template and
  behavioural tests.
- Both templates carry the same "Locate the proj-site tile" step, and no job
  `env` sets `SITE_TILE`.
- A managed-mode throwaway repo with an empty HOME and no `TESSL_*`
  variables, pinned to the published `0.4.0` and another dependency: the
  step installs only proj-site, in a temporary folder, anonymously; the
  workspace and its `tessl.json` are untouched; the tile builds a site.
- A `file:` source is used as it stands; a nonexistent version and an unlisted
  proj-site both fail with their own messages, not a later "file not found"
  (step 6, in Progress notes).
- This repository's regenerated workflows run green on a PR, and its Pages
  deploy publishes after merge.
- On each already opted-in project: the regenerated check workflow fails
  without an entry and passes with one, and the Pages deploy publishes
  (step 7).

## Progress notes

- 2026-11-26, steps 1-5 on branch `chore-tile-install` (#37): all 113 tests
  pass locally and in CI. This repository's regenerated workflows took the
  `file:tile` route in Actions ("Locate the proj-site tile" set
  `SITE_TILE: tile`) and the Pages deploy published after merge. The PR's
  Site check reported a missing entry only because it ran after `land` had
  merged; the entry (named for the branch, `2026-11-26-chore-tile-install.md`,
  because the plan's suggested name was the plan PR's entry) is on `dev`.
- 2026-11-26, step 6: the maintainer published `0.4.0` (Public; moderation
  passed; quality 95%, security Low). With the trunk's locate script, an
  empty HOME, no `TESSL_*` variables and the real `npx`:
  - pinning `0.4.0` beside `mhclg-aaai/myelin`: exit 0; the output never
    mentions myelin; the temporary folder's plugins hold only proj-site, at
    manifest version `0.4.0`; the workspace has no `.tessl/` and its
    `tessl.json` is byte-identical; `site-init.sh --content-type knowledge`
    and, with the stub source, `build.sh` built the site.
  - `"source": "file:tilecopy"`: exit 0, `SITE_TILE=tilecopy`, no `npx`
    call, nothing under `RUNNER_TEMP`.
  - version `9.9.9`: exit 1, "The proj-site tile (version 9.9.9, from
    tessl.json) was not installed at ...".
  - proj-site not listed: exit 1, "tessl.json does not list
    mhclg-aaai/proj-site."
- 2026-11-26, step 7: no other project is opted in. A code search of the
  organisation finds `mhclg-aaai/proj-site` only in this repository's
  `tessl.json`, and myelin's `dev` has no `site/` or site workflows; the
  myelin pilot stays with plan 0001 step 13 and will use the new templates.
