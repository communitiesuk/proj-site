#!/usr/bin/env bash
# scan-site.sh <project-dir> <public-dir>
#
# Verification only (plan 0001), not CI enforcement: scan a built site for the
# project's git author and committer names and for common secret patterns.
# Prints one line per finding (file, and the name or the pattern's label; a
# secret's value is never printed) and exits 1 if anything is found, else 0.
# Names that are services rather than people ("GitHub", "*[bot]") are skipped.
set -eu
project=$1; public=$2
found=0
while IFS= read -r name; do
  case $name in ""|GitHub|*"[bot]") continue;; esac
  while IFS= read -r f; do echo "name: $name in ${f#"$public"/}"; found=1; done \
    < <(grep -rliF -- "$name" "$public" || true)
done < <(git -C "$project" log --format='%an%n%cn' | sort -u)
for pair in 'github-token:gh[pousr]_[A-Za-z0-9]{30,}' 'github-pat:github_pat_[A-Za-z0-9_]{20,}' \
            'aws-key:AKIA[0-9A-Z]{16}' 'private-key:-----BEGIN [A-Z ]*PRIVATE KEY-----' 'slack-token:xox[baprs]-[A-Za-z0-9-]{10,}'; do
  label=${pair%%:*}; re=${pair#*:}
  while IFS= read -r f; do echo "secret: $label in ${f#"$public"/}"; found=1; done \
    < <(grep -rlE -- "$re" "$public" || true)
done
exit $found
