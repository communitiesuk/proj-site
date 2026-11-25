#!/usr/bin/env bash
#
# Fixture for evals/site-setup-0.
#
# A myelin-style repository that has not opted into proj-site: tessl in
# managed mode, an origin remote naming example/beacon, a trunk called dev,
# and Python source. The task asks only that the project site be set up; the
# site-setup skill must run its opt-in script rather than hand-writing files.
#
#   - Python under src/: lets the "content type both, languages [python]"
#     criterion fail when an agent guesses.
#   - Trunk dev: lets the "Pages workflow deploys from dev" criterion fail.
#   - No mention of Claude Code hooks: lets the "no hook unless asked"
#     criterion fail.
#   - Tag fixture-base: lets "committed after the fixture" be scored.
#   - Managed mode: lets "tessl.json keeps managed mode" fail when an agent
#     switches it to vendored, which proj-site no longer requires.
set -eu
git init -q .
git symbolic-ref HEAD refs/heads/dev
git config --local user.name "Beacon Maintainers"
git config --local user.email "maintainers@example.invalid"
git config --local commit.gpgsign false
git remote add origin https://github.com/example/beacon.git
printf '{"name":"beacon","mode":"managed","dependencies":{}}\n' > tessl.json
printf '# Beacon\n\nBeacon flags late planning applications.\n' > README.md
mkdir -p src && printf 'def late(apps):\n    """Return the applications past their deadline."""\n    return []\n' > src/beacon.py
git add -A && git commit -q -m "Initial Beacon"
git tag fixture-base
