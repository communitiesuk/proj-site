---
name: site-update
description: Keeps a proj-site project's hand-written user documentation — site/content/overview.md, the long-form docs under site/content/docs/, and code docstrings — aligned with what the project actually contains, editing passages that describe removed, renamed or changed behaviour. TRIGGER before raising a pull request that changes code or docs in a repository with site/project.yaml, or when asked to bring the site's docs up to date. SKIP for the per-PR entry and weekly summary (use the `site-writing` skill), for generated reference docs (built from docstrings at deploy time), and for repositories without site/project.yaml.
---

# Site update
