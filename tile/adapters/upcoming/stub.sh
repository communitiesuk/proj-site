#!/usr/bin/env bash
# Upcoming-work adapter: fixed output, to show the source is swappable.
#
# Usage: stub <project-dir>
#
# Writes <project-dir>/site/upcoming-stub.json to stdout if it exists, else
# the single item [{"title":"Stub item","ref":"#0","state":"open","theme":""}].
f="$1/site/upcoming-stub.json"
if [ -f "$f" ]; then cat "$f"
else echo '[{"title":"Stub item","ref":"#0","state":"open","theme":""}]'; fi
