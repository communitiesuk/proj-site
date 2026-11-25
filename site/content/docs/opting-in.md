---
title: Opting a project in
weight: 1
---
## Requirements

- A myelin project on GitHub that uses tessl, in any mode. The site's
  workflows install the tile from the project's `tessl.json` on each run, so
  they need network access to the tessl registry.
- Bash 4 or later, `git`, `gh` and `jq`. The Pages workflow installs Hugo
  itself.

## Steps

1. Install the tile:

   ```sh
   tessl install mhclg-aaai/proj-site
   ```

2. Run the opt-in script from the repository root:

   ```sh
   bash .tessl/plugins/mhclg-aaai/proj-site/skills/site-setup/scripts/site-init.sh [--content-type knowledge|code|both] [--trunk <branch>] [--with-claude-hook]
   ```

   It creates `site/project.yaml`, a stub `site/content/overview.md`, and two
   workflows: one that checks every pull request, and one that builds and
   deploys the site. `--with-claude-hook` also stops Claude Code from raising a
   pull request before the per-PR entry exists. Running it again changes
   nothing.

3. Edit `site/content/overview.md`, and add long-form guides under
   `site/content/docs/`.
4. Enable GitHub Pages for the repository, with **GitHub Actions** as the
   source.
5. Raise the opt-in pull request with its own per-PR entry.

Existing weeknotes are not migrated: the first weekly summary is written from
the project's history.
