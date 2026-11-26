---
name: site-setup
description: Opts a myelin project into proj-site and builds or previews its public site — running the opt-in script that creates site/project.yaml, the overview stub and the check and Pages workflows, and running the site build locally. Also holds the site's build core, adapters and scripts. TRIGGER when asked to opt a project into proj-site, set up or add the project site, enable the site's GitHub Pages deploy, or build or preview the site locally. SKIP for writing per-PR entries or weekly summaries (use `site-writing`), for aligning docs with code (use `site-update`), and for repositories that already have site/project.yaml unless asked to build or preview.
---

# Site setup

proj-site gives a project a public site on GitHub Pages, with the tabs Overview, Guides (`/guides/`), Docs (`/docs/`, with generated reference under `/docs/reference/`), Weeknotes (`/weeknotes/`), Latest updates (`/updates/`: per-PR entries and a timeline read from the git history) and Coming next (`/coming-next/`). This skill opts a project in and builds the site. Its directory also holds the runtime every opted-in project uses: `core/` (the build), `adapters/`, `scripts/` and `templates/`.

The harness states this skill's base directory when it loads the skill. Call it `$SKILL_DIR`. Run every script with `bash` (or `python3` for `.py`): the registry does not keep executable bits.

## Opting a project in

1. **Check the prerequisites.** The repository root is the working directory; the tile is installed (`tessl install mhclg-aaai/proj-site`), so `tessl.json` lists it. Any tessl mode works, so leave the project's mode as it is: the workflows read proj-site's entry in `tessl.json` and install only proj-site at that version into a temporary folder (or use a `file:` source as it stands), never the project's other dependencies.
2. **Run the opt-in script.** Do not hand-write the files it creates:

   ```sh
   bash "$SKILL_DIR/scripts/site-init.sh" [--content-type knowledge|code|both] [--trunk <branch>] [--with-claude-hook]
   ```

   - Leave `--content-type` out unless the user names one: the script picks `both` when the project has Python and `knowledge` otherwise. Pass it when the detection is wrong for the project, for example a tooling repository whose users want guides, not reference pages.
   - Pass `--with-claude-hook` only when asked for it. It registers `scripts/hook-pr-create.sh` in `.claude/settings.json`, which blocks raising a pull request until the branch has its per-PR entry. `scripts/check-pr.sh` is the check the PR workflow runs.
   - It creates only what is missing, so re-running it is safe. A project opted in with earlier templates regenerates its workflows by deleting `.github/workflows/site-check.yml` and `site-pages.yml` first, then re-running it.
3. **Review what it created**: `site/project.yaml`, `site/content/overview.md` and `.github/workflows/site-check.yml` and `site-pages.yml`. Fill in the overview from the README in plain language; everything under `site/` is public (no named people, no secrets).
4. **Build locally** (below) to confirm the site renders.
5. **Commit** the files on the opt-in branch. Before raising the pull request, the `site-writing` skill writes the per-PR entry, and the first weekly summary, which is always due on opt-in.
6. **Enable GitHub Pages** with GitHub Actions as the source, when the user has GitHub access: `gh api -X POST repos/<owner>/<repo>/pages -f build_type=workflow`. This publishes a public site, so confirm with the user first. Without access, list it as a next step.
7. **Offer to require the site check.** Ask the user to confirm making the site check (the `check` job) a required status on the trunk. Say that a pull request then cannot merge while the check fails; that it adds only the site check, sets no up-to-date requirement and keeps existing protection settings; that on an unprotected trunk it also blocks force pushes to and deletion of the trunk; and that administrators can still bypass it. On confirmation, run `bash "$SKILL_DIR/scripts/require-site-check.sh" --trunk <trunk>` and act on its exit code:
   - **0**: the check is required (or already was); say which.
   - **1**: it failed; list the step as a next step with the `gh api` line or `Set it by hand:` line it printed.
   - **2**: a usage error; fix the invocation and run it again.
   - **3**: the trunk's protection has no required status checks; list its `Set it by hand:` line as a next step.

   Without confirmation, list the step as a next step with the script's command line.

Pushing a commit that adds workflows needs a token with the `workflow` scope; if a push is refused for that, ask the user to run `gh auth refresh -s workflow`.

## Building or previewing the site

```sh
SITE_OFFLINE=1 bash "$SKILL_DIR/core/build.sh" . <out-dir>          # renders <out-dir>/public
hugo server --source <out-dir>/src                                  # preview
```

`SITE_OFFLINE=1` skips the GitHub lookups for PR numbers; the upcoming-work adapter still calls GitHub unless `upcoming.source` is `stub`. Build errors name the failing step (the project file, an adapter, or Hugo).

## Do not

- Do not hand-write `project.yaml` or the workflows; run the script, then edit.
- Do not add the Claude Code hook unless asked.
- Do not enable Pages without the user's confirmation; it publishes the site.
- Do not require the site check without the user's confirmation, and do not change any other branch-protection setting.
- Do not migrate the gitignored `weeknotes/` folder into `site/`.
