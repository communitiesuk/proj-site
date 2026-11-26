---
title: Offer the site check as a required status at opt-in
status: draft
adr: 0001
date: 2026-11-26
deferred_reason: null
---

# Offer the site check as a required status at opt-in

Implements [ADR 0001](../docs/adr/0001-project-site.md) as revised in PR #40
(enforcement: the opt-in offers branch protection). The rest of the ADR is
implemented; the myelin pilot stays with [plan 0001](0001-project-site.md).
This repository's own trunk is not touched by this plan.

## Steps

Paths under `S/` mean `tile/skills/site-setup/`. Steps 1 to 5 land on one
implementation branch. The maintainer publishes from the trunk (step 6), and
the rest of step 6 and steps 7 and 8 land on a final branch. Each commit that
changes `tile/` also runs `tessl install`, refreshing this repository's
vendored `.tessl/plugins/mhclg-aaai/proj-site`.

The required status is the check workflow's job, named `check`
(`S/templates/workflows/site-check.yml.txt`). Only that status is required;
branches are not required to be up to date with the trunk.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

1. **A script that requires the check.** Add
   `S/scripts/require-site-check.sh [--trunk <branch>] [--repo <owner/name>]`.
   The trunk defaults as in `site-init.sh` (origin/HEAD, else the first
   existing of `dev`, `main`, `master`); the repository defaults to the
   origin remote's `owner/name`. It uses only `gh api` and `jq`, and
   changes nothing but the trunk's required status checks:
   - `gh api repos/<repo>/branches/<trunk>/protection` answers 404 (the
     trunk is unprotected): `PUT` it with `--input` JSON of
     `required_status_checks` `{"strict": false, "checks": [{"context": "check"}]}`
     and `enforce_admins`, `required_pull_request_reviews` and `restrictions`
     all `null`; print that the check is now required.
   - Protection exists with `required_status_checks`, and `check` is not
     among its contexts: `POST
     repos/<repo>/branches/<trunk>/protection/required_status_checks/contexts`
     with `["check"]`, which keeps the other contexts and the `strict`
     setting; print that the check was added.
   - `check` is already required: change nothing and print so.
   - Protection exists without `required_status_checks`: change nothing,
     print the one `gh api` command the user can run after reviewing, exit 3.
   - Any other `gh` failure (no admin rights answers 403 or 404 on the
     write, or no `gh` login): change nothing, print the response and the
     same manual command, exit 1.
   - A usage error, or not at a git repository's root with no `--repo`:
     exit 2.

   Change `tests/` first. Add `tests/test_require_check.sh`, with a stub `gh`
   first on `PATH` that logs each call (method, path, stdin) and answers from
   fixture files, and a fixture repo with origin
   `https://github.com/example/widget.git`. Assert for each case above: the
   calls made (the unprotected case `PUT`s exactly the JSON above to
   `repos/example/widget/branches/dev/protection`; the exists-with-checks case
   makes no `PUT`; the already-required case makes only the `GET`), the exit
   code, and that stdout names the outcome; `--trunk`/`--repo` override the
   defaults; `strict` is never sent as `true`. Docstring: the script's
   header comment, in the style of `site-init.sh`. Run `tests/run.sh
   require_check` until it passes, then `tests/run.sh`.

   Commit: the script and its tests.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

2. **The opt-in script lists it as a next step.** In `S/scripts/site-init.sh`,
   add to the "Next steps" it prints, after the Pages step, a step
   "Require the site check on `<trunk>` (needs admin rights): `bash
   <tile>/skills/site-setup/scripts/require-site-check.sh --trunk <trunk>`",
   with the trunk it resolved; renumber the PR step. Update the header
   comment's "next steps" list. In `tests/test_init.sh`, first extend
   `test_init_creates_project_and_workflows` to assert the output contains
   `require-site-check.sh --trunk dev`, and `test_init_detects_python_and_trunk`
   to assert `--trunk main`. `site-init.sh` itself never calls `gh` or
   changes settings, and the existing second-run test still passes.

   Commit: the script and `tests/test_init.sh`.

3. **The skill offers it.** In `S/SKILL.md`, edit the body only; the
   frontmatter `description` stays unchanged. Insert after step 6 ("Enable
   GitHub Pages") a step 7, "Offer to require the site check":
   - Ask the user to confirm making the site check a required status on the
     trunk, saying that a pull request then cannot merge while the check
     fails, and that branches need not be up to date.
   - On confirmation, and when the user has admin rights on the repository,
     run `bash "$SKILL_DIR/scripts/require-site-check.sh" --trunk <trunk>`.
     Relay its outcome. The check only becomes selectable after the workflow
     has run once on the trunk or a PR, so when the script reports failure
     for that or for missing rights, list the step as a next step instead.
   - Without confirmation or admin rights, list the step as a next step with
     that command.

   Add to "Do not": do not require the check without the user's confirmation
   and admin rights, and do not change any other branch-protection setting.
   Update step 1's wording only where the opt-in sequence numbers change.
   Run `tests/run.sh`; confirm `tile/evals/site-setup-0/` needs no change (its
   task skips anything needing GitHub, and no criterion mentions branch
   protection) by reading `criteria.json` and `task.md`.

   Commit: `S/SKILL.md`.

4. **Docs match.** Edit:
   - `README.md`, "Opting in": after the "Then enable GitHub Pages" paragraph,
     add a paragraph: the opt-in offers to make the site check (the `check`
     job) a required status on the trunk, through branch protection, with the
     user's confirmation and admin rights, and otherwise lists it as a next
     step; it can be run alone with `require-site-check.sh --trunk <branch>`;
     only the site check is required and branches need not be up to date; a
     project using myelin's `land` finds that its merge straight after
     opening the PR is refused while the check runs, until myelin #216 is
     fixed. Add `require-site-check.sh` to any scripts table in the README
     that lists the opt-in scripts.
   - `site/content/guides/opting-in.md`: insert a step after step 4,
     "Make the site check required on the trunk" (admin rights needed; with
     the script command, and the equivalent in the repository's Settings,
     Branches, "Require status checks to pass", selecting `check`); renumber
     the PR step; add the `land` caveat in one sentence. Add to Requirements
     that admin rights on the repository are needed for that step only.
   - `site/content/docs/how-it-works.md`, "What is checked": add one
     sentence that a project can make the check required, so that a pull
     request cannot merge while it fails.

   Then run `site-update` over the changed docs. Commit: the docs.

5. **Version and entry.** Bump `version` in `tile/.tessl-plugin/plugin.json`
   to `0.5.0` and run `tessl install` to refresh the vendored copy. Write
   this change's per-PR entry (`site-writing`) at
   `site/content/changes/<date>-plan-0005-required-site-check.md`, dated the
   day it is written, before the PR is opened. Commit: manifest, vendored
   refresh, entry.

6. **Publish and verify.** After the implementation branch lands on the
   trunk (`dev`), the maintainer publishes from their local login with
   `tessl plugin publish tile` and confirms with
   `tessl plugin info mhclg-aaai/proj-site` that `0.5.0` is listed and the
   visibility is Public. Then, in a throwaway folder with an empty HOME and
   no `TESSL_*` variables, run `npx -y @tessl/cli@0.123.0 install --yes
   --accept-warnings` with a `tessl.json` whose only dependency is
   `mhclg-aaai/proj-site` at `0.5.0`, and check that
   `.tessl/plugins/mhclg-aaai/proj-site/skills/site-setup/scripts/require-site-check.sh`
   exists, that `bash` on it with the stub `gh` of step 1 first on `PATH`
   makes the unprotected-case `PUT`, and that `site-init.sh` run in a
   throwaway git repo prints the require-the-check next step. Record the
   results in Progress notes on the final branch. If the `0.5.0` install
   fails, stop and report.

7. **Prove it on a real repository.** In a throwaway repository the
   maintainer owns, never this repository, with the published `0.5.0`
   installed, opted in by the skill (`site-init.sh --trunk dev`) with its
   workflows merged on `dev`:
   - Run `require-site-check.sh --trunk dev`; confirm with
     `gh api repos/<owner>/<repo>/branches/dev/protection/required_status_checks`
     that `contexts` holds `check` and `strict` is `false`. Run it again:
     it reports no change.
   - Open a PR with no per-PR entry; once the check has failed,
     `gh pr view --json mergeStateStatus` shows `BLOCKED`, and
     `gh pr merge` is refused. Add the entry; once the check passes,
     `mergeStateStatus` is `CLEAN`.
   - On a second throwaway repository with `dev` already protected with a
     different required context, the script adds `check` and keeps that
     context.
   - With a token lacking admin rights (or a repository the account only has
     write access to), the script exits 1, changes nothing and prints the
     manual command.

   Record the four results in Progress notes. Delete the throwaway
   repositories afterwards.

8. **Completion.** Delete this plan in the final commit of the final branch,
   after steps 6 and 7's records are committed, with the `Completes:` trailer
   and a body saying what the plan produced. Write a release per-PR entry in
   `site/content/changes/` in the same branch.

## Verification

- `tests/run.sh` passes in CI, including `tests/test_require_check.sh` and
  the extended `tests/test_init.sh`.
- `site-init.sh` prints the require-the-check next step with the resolved
  trunk, and still creates and changes nothing else.
- `tile/skills/site-setup/SKILL.md` offers the step with confirmation and
  admin rights, and its `description` is unchanged.
- The published `0.5.0` carries `require-site-check.sh` (step 6).
- On a real throwaway repository: the check becomes a required status with
  `strict` false, a PR without an entry cannot merge and one with it can,
  existing required contexts are kept, and a missing right changes nothing
  (step 7).
- This repository's `dev` protection is untouched.

## Progress notes
