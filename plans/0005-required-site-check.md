---
title: Offer the site check as a required status at opt-in
status: in-progress
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
   It resolves the trunk as `site-init.sh` does; the repository defaults to
   the origin remote's `owner/name`. It uses `git`, `gh` and `jq`. On existing
   protection it changes only the required status checks; on an unprotected
   trunk it creates protection, which also blocks force pushes to and deletion
   of the trunk. It requires the status `check` with no `app_id`, so GitHub
   selects the app. It first reads
   `gh api repos/<repo>/branches/<trunk>/protection`, then:
   - 404 with the message "Branch not protected": `PUT` the same path with
     `--input` of exactly this JSON, `P`:
     `{"required_status_checks":{"strict":false,"checks":[{"context":"check"}]},"enforce_admins":null,"required_pull_request_reviews":null,"restrictions":null}`;
     print `Required the site check on <trunk>.`, exit 0.
   - `required_status_checks` present, `check` not among its contexts: `POST
     repos/<repo>/branches/<trunk>/protection/required_status_checks/contexts`
     with `--input` of exactly `{"contexts":["check"]}`, `C`, which keeps the
     other contexts and `strict`; print `Added the site check to the required
     checks on <trunk>.`, exit 0.
   - `check` already among the contexts (in `contexts` or `checks[].context`):
     change nothing, print `The site check is already required on <trunk>;
     nothing changed.`, exit 0.
   - Protection present without `required_status_checks`: change nothing,
     print only the line `Set it by hand: https://github.com/<repo>/settings/branches`
     ("Require status checks to pass", selecting `check`), no `gh api` text,
     exit 3.
   - A failed `PUT` or `POST`, so the state was read: change nothing more,
     print the `gh` error to stderr and, on stdout, the call the script would
     have made for that state, one line each: for the unprotected state
     `echo '<P>' | gh api -X PUT repos/<repo>/branches/<trunk>/protection --input -`,
     for the other state
     `echo '<C>' | gh api -X POST repos/<repo>/branches/<trunk>/protection/required_status_checks/contexts --input -`
     (with the JSON written out); exit 1. A call that would replace existing
     protection is never printed.
   - Any other failure of the first read (no `gh` login, no admin rights
     answering 403 or 404 "Not Found", no network), so the state is unknown:
     change nothing, print the `gh` error to stderr and the `Set it by hand:`
     line above to stdout, no `gh api` text, exit 1.
   - A usage error, no `--trunk` outside a git repository, or no `--repo` and no
     origin remote: exit 2.

   Change `tests/` first. Add `tests/stub-gh.sh`, a stub `gh` that appends
   each call (method, path, stdin) to `$STUB_GH_DIR/calls` and answers from
   fixture files in `$STUB_GH_DIR`, one file per response named for the request,
   committed under `tests/stub-gh/`, copying `gh api`'s failure form: exit 1,
   `gh: <message> (HTTP <code>)` on stderr, the JSON body on stdout. Add
   `tests/test_require_check.sh`, which puts the stub first on `PATH` as
   `gh` and uses a fixture repo with origin
   `https://github.com/example/widget.git`. Assert for each case above the
   calls made, the exit code and stdout: unprotected `PUT`s exactly `P` to
   `repos/example/widget/branches/dev/protection`; exists-with-checks makes
   one `POST` of exactly `C` and no `PUT`; already-required makes only the
   `GET`; exit 3 stdout is exactly the `Set it by hand:` line, with no
   `gh api` and no write call; exit 1 after a failed `PUT` or `POST` prints
   the exact line above for its state, and after a failed first read prints
   the `Set it by hand:` line and no `gh api`; a failed `POST` never prints a
   `PUT`; exit 2 for `--repo` without `--trunk` outside a repository, which
   `--repo` with `--trunk` there does not; `--trunk`/`--repo` override the
   defaults; `strict` is never sent as `true`. Docstring: the script's header
   comment, in the style of `site-init.sh`. Run `tests/run.sh require_check`
   until it passes, then `tests/run.sh`.

   Commit: the script, the stub, its fixtures and the tests.

> **Directive for the implementer**: this step will write or modify executable code. Load the `test-first-workflow` skill before writing the code (docstrings → failing tests → code).

2. **The opt-in script lists it as a next step.** In `S/scripts/site-init.sh`,
   add after the Pages step the line `  3. Require the site check on <trunk>
   (needs admin rights): bash
   .tessl/plugins/mhclg-aaai/proj-site/skills/site-setup/scripts/require-site-check.sh --trunk <trunk>`,
   with the trunk it resolved, and renumber the PR step to 4. Update the
   header comment's "next steps" list. In `tests/test_init.sh`, first extend
   `test_init_creates_project_and_workflows` to assert the output contains
   `require-site-check.sh --trunk dev`, and `test_init_detects_python_and_trunk`
   (which discards the output now; capture it) to assert `--trunk main`.
   `site-init.sh` itself never calls `gh` or changes settings, and the
   existing second-run test still passes.

   Commit: the script and `tests/test_init.sh`.

3. **The skill offers it.** In `S/SKILL.md`, edit the body only; the
   frontmatter `description` stays unchanged. Insert after step 6 ("Enable
   GitHub Pages") a step 7, "Offer to require the site check":
   - Ask the user to confirm making the site check a required status on the
     trunk, saying that a pull request then cannot merge while the check
     fails, that it adds only the site check, sets no up-to-date requirement and
     keeps existing protection settings, that on an unprotected
     trunk this also blocks force pushes to and deletion of the trunk, and
     that administrators can still bypass it.
   - On confirmation, run
     `bash "$SKILL_DIR/scripts/require-site-check.sh" --trunk <trunk>` and
     relay its outcome by exit code: 0, the check is required (or already
     was); 1, a failure, so list the step as a next step with the `gh api`
     line or `Set it by hand:` line it printed; 2, a usage error, so fix the
     invocation and run again; 3, the trunk's protection has no required
     status checks, so list the `Set it by hand:` line as a next step.
   - Without confirmation, list the step as a next step with the script's command line.

   Add to "Do not": do not require the check without the user's confirmation,
   and do not change any other branch-protection setting.

   Run `tests/run.sh`; confirm `tile/evals/site-setup-0/` needs no change (its
   task skips anything needing GitHub, and no criterion mentions branch
   protection) by reading `criteria.json` and `task.md`.

   Commit: `S/SKILL.md`.

4. **Docs match.** Edit:
   - `README.md`, "Opting in": as the last paragraph of the "## Opting in"
     introduction, immediately before "### Projects already opted in", add a
     paragraph: the opt-in offers to make the site check (the `check`
     job in `site-check.yml`) a required status on the trunk, through branch
     protection, with the user's confirmation, and otherwise lists it as a
     next step; it can be run alone with
     `require-site-check.sh --trunk <branch>`; it adds only the site
     check, sets no up-to-date requirement and keeps existing protection
     settings; on an unprotected trunk it
     creates protection, which also blocks force pushes to and deletion of the
     trunk; administrators can still bypass it; a
     project using myelin's `land` finds that its merge straight after
     opening the PR is refused while the check runs, until myelin #216 is
     fixed. In the "What ships" table, edit the `S/scripts/` row to name the
     script that requires the check.
   - `site/content/guides/opting-in.md`: insert a step after step 4,
     "Make the site check required on the trunk" (admin rights needed; the required
     status is the job `check` in `site-check.yml`; with the script command, and the equivalent in the repository's Settings,
     Branches, "Require status checks to pass", selecting `check`), saying that on an unprotected trunk
     it also blocks force pushes to and deletion of the trunk and that
     administrators can still bypass it; renumber the PR step; add the `land`
     caveat in one sentence. Add to Requirements
     that admin rights on the repository are needed for that step only.
   - `site/content/docs/how-it-works.md`, "What is checked": add one
     sentence that a project can make the check required, so that a pull
     request cannot merge while it fails.

   Then run `site-update` over the changed docs. Commit: the docs.

5. **Version and entry.** Bump `version` in `tile/.tessl-plugin/plugin.json`
   to `0.5.0` and run `tessl install` to refresh the vendored copy. Write
   this change's per-PR entry (`site-writing`) at
   `site/content/changes/<date>-<branch-slug>.md` (`<branch-slug>` is the
   implementation branch's, as `site-writing` defines it), dated the day it is
   written, before the PR is opened. Commit: manifest, vendored
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
   exists, that `bash` on it with `--repo example/widget --trunk dev`, with
   `tests/stub-gh.sh` copied out as `gh` first on `PATH` and `STUB_GH_DIR`
   set to a copy of the unprotected set in `tests/stub-gh/`, logs the unprotected-case `PUT`, and that `site-init.sh` run in a
   throwaway git repo prints the require-the-check next step. Record the
   results in Progress notes on the final branch. If the `0.5.0` install
   fails, stop and report.

7. **Prove it on a real repository.** First read
   `gh api repos/communitiesuk/proj-site/branches/dev/protection` and record
   it. In public throwaway repositories the maintainer owns (never this
   repository; branch protection needs a public repository or a paid plan),
   with the published `0.5.0` installed:
   - On a fresh repository, run the opt-in itself through the `site-setup`
     skill (`site-init.sh --trunk dev`): decline the offer, and record that it asked for confirmation first, did
     not run the script, and listed the step as a next step. Ask for the offer
     again and confirm; record that the script ran only after the
     confirmation. Confirm with
     `gh api repos/<owner>/<repo>/branches/dev/protection/required_status_checks`
     that `contexts` holds `check` and `strict` is `false`. Merge its
     workflows on `dev`. Read `dev`'s protection, run
     `require-site-check.sh --trunk dev` directly, and read it again: it
     reports no change and the two reads are identical. The bullets below
     need a repository already opted in with its workflows merged on `dev`.
   - Open a PR with no per-PR entry; once the check has failed,
     `gh pr view --json mergeStateStatus` shows `BLOCKED`, and
     `gh pr merge` is refused. Add the entry, and the weekly summary if the
     check reports one due; once the check passes, `mergeStateStatus` is
     `CLEAN`. This also confirms the real API accepted the `checks` form.
   - On a second throwaway repository with `dev` already protected with a
     different required context, the script adds `check` and keeps that
     context.
   - With a token lacking admin rights (or a repository the account only has
     write access to), the script exits 1 and prints the
     `Set it by hand:` line and no `gh api` text; `dev`'s protection, read
     with an admin token before and after, is identical.

   Read the `proj-site` `dev` protection again, and record the results
   and both reads in Progress notes. Delete the throwaway repositories
   afterwards.

8. **Completion.** Delete this plan in the final commit of the final branch,
   after steps 6 and 7's records are committed, with the `Completes:` trailer
   and a body saying what the plan produced. Write the final branch's per-PR entry
   (`site-writing`) in `site/content/changes/` before its PR is opened.

## Verification

- `tests/run.sh` passes in CI, including `tests/test_require_check.sh` and
  the extended `tests/test_init.sh`.
- `site-init.sh` prints the require-the-check next step with the resolved
  trunk, and still creates and changes nothing else.
- `tile/skills/site-setup/SKILL.md` offers the step with confirmation, and its `description` is unchanged.
- On exits 1 and 3 the script prints only the lines step 1 gives, and never a
  call that would replace existing protection.
- The published `0.5.0` carries `require-site-check.sh` (step 6).
- On a real throwaway repository: the check becomes a required status with
  `strict` false, a PR without an entry cannot merge and one with it can,
  existing required contexts are kept, and a missing right changes nothing
  (step 7).
- This repository's `dev` protection reads the same before and after step 7.

## Progress notes

- 2026-11-26, steps 1-5 on branch `chore-required-site-check` (#43): all 124
  tests pass locally and in CI; the Pages deploy published after merge. Two
  expectations in `tests/test_require_check.sh` lost a trailing space after
  the red commit and were rebuilt with `printf` in a separate commit. The
  PR's Site check reported a missing entry only because it ran after `land`
  had merged; the entry is on `dev`.
- 2026-11-26, step 6: the maintainer published `0.5.0` (Public; moderation
  passed; quality 93%, security Medium). Installed anonymously in a
  throwaway folder (manifest `0.5.0`), `require-site-check.sh` is present;
  run with `--repo example/widget --trunk dev` against the copied-out stub
  and the unprotected fixtures it printed "Required the site check on dev.",
  exited 0 and logged the GET then the PUT; the installed `site-init.sh`
  prints "3. Require the site check on dev (needs admin rights): ...".
- 2026-11-26, step 7, in public throwaway repositories under the
  maintainer's account (`proj-site-protect-a`, `-b`), with `0.5.0`
  installed. `communitiesuk/proj-site`'s `dev` read "Branch not protected"
  before and after.
  - Repository A: an agent following the site-setup skill ran
    `site-init.sh --trunk dev`, then stopped and asked for confirmation,
    with the skill's explanation, before touching protection. Declined: it
    ran nothing, protection stayed unprotected, and it listed the step with
    the script's command line. Offered again and accepted: it invoked the
    script, which Claude Code's auto-mode classifier refused as a
    destructive action, so the maintainer ran the same command; it printed
    "Required the site check on dev." `required_status_checks` then held
    `contexts: ["check"]`, `checks: [{"context":"check","app_id":null}]`,
    `strict: false`; force pushes and deletion off, admins not enforced, no
    reviews. A PR with no entry failed the check; `mergeStateStatus` was
    `BLOCKED` and `gh pr merge` was refused ("the base branch policy
    prohibits the merge", even for an admin without `--admin`). With the
    entry and the due weeknote the check passed and it was `CLEAN`. Run
    again, the script printed "The site check is already required on dev;
    nothing changed." and the protection read identical before and after.
  - Repository B, `dev` protected requiring `test` with `strict: true`: the
    script printed "Added the site check to the required checks on dev.";
    the contexts became `["test","check"]` and `strict` stayed `true`.
  - The no-admin case was not run: no token or account without admin rights
    was available. The stub tests cover its output.
  - Both throwaway repositories were deleted by the maintainer.
