#!/usr/bin/env bash
# timeline.sh <project-dir> [<since-YYYY-MM-DD>]
#
# Read the git graph of <project-dir> (HEAD and everything reachable from it) and
# print, to stdout, a JSON array of timeline events, oldest first:
#
#   {"date": "YYYY-MM-DD", "stage": "explored"|"decided"|"built"|"shipped",
#    "kind": <kind>, "path": <artefact path or tag>, "title": <str>,
#    "commit": <short sha>, "recent": <bool>}
#
# Kinds and their stages:
#   discovery-added  explored  a commit adds docs/discovery/NNNN-*.md
#   adr-added        decided   a commit adds docs/adr/NNNN-*.md
#   adr-revised      decided   a commit carries `Revises: <adr>`
#   note-consumed    decided   a commit carries `Consumed-By: <adr>` (path is the ADR)
#   plan-added       decided   a commit adds plans/NNNN-*.md
#   plan-abandoned   decided   a commit carries `Abandons: <plan>`
#   plan-completed   built     a commit carries `Completes: <plan>`
#   release          shipped   a tag points at a commit (path is the tag name)
#
# `title` is the artefact's front-matter `title`, read from the commit (or its
# parent when the commit deletes the file); otherwise the commit subject, or the
# tag name for releases. Each (kind, path) appears once, at its earliest commit.
# `recent` is true when date >= <since>; when <since> is omitted every event is
# recent. `Derives-From` adds no event: it links artefacts already listed.
# Prints `[]` for a repository with no matching history. Exits 2 if
# <project-dir> is not a git repository.
:
