---
title: Opting a project in
weight: 1
---
## Requirements

- A myelin project on GitHub that uses tessl, in any mode, with
  `mhclg-aaai/proj-site` in its `tessl.json`. On each run the site's
  workflows install only proj-site, at that version, into a temporary folder,
  so they need network access to the tessl registry; the project's other
  dependencies are never installed.
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

3. Edit `site/content/overview.md`. Add step-by-step guides under
   `site/content/guides/` (the Guides tab) and technical documentation under
   `site/content/docs/` (the Docs tab).
4. Enable GitHub Pages for the repository, with **GitHub Actions** as the
   source.
5. Raise the opt-in pull request with its own per-PR entry.

A gitignored `weeknotes/` folder, kept private on purpose, is not migrated:
the first public weeknote is written from the project's history.

## Showing a summary on Coming next

The Coming next tab lists open issues by title, link and theme (the issue's
first `theme:<name>` label). It shows no text from an issue unless the
issue's author opts some in, with a section headed `## Site summary` in the
issue body:

```markdown
## Site summary

Readers will be able to filter the list by date.
```

The text up to the next heading becomes the row's expandable summary.
Nothing else in the issue appears on the site, so write that section for a
public reader.

## If the project is already opted in

The opt-in script never overwrites files, so a project opted in with an
earlier version of proj-site keeps its old workflows. To update them, delete
`.github/workflows/site-check.yml` and `site-pages.yml`, run the opt-in script
again (with `--trunk <branch>` if it cannot find the trunk), check the diff
for any local changes worth keeping, and commit the two workflows in a pull
request with its own per-PR entry.
