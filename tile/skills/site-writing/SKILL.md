---
name: site-writing
description: Writes the public project site's stakeholder content in a project opted into proj-site — the per-PR entry under site/content/changes/ and, when one is due, the weekly summary under site/content/summaries/ — following the public content rules. TRIGGER before raising or opening a pull request in a repository that has site/project.yaml, when the site check reports a missing entry or a due summary, or when asked to write the week's summary. SKIP for repositories without site/project.yaml, for editing the overview or long-form docs to match the code (use the `site-update` skill), and for private notes such as weeknotes.
---

# Site writing
