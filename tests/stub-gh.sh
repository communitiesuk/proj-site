#!/usr/bin/env bash
# A stub `gh` for tests: handles `gh api [-X <method>] <path> [--input -]`.
# Appends "<method> <path> <stdin>" to $STUB_GH_DIR/calls, then answers from
# $STUB_GH_DIR/<method>-<last path segment> (e.g. GET-protection,
# POST-contexts): its first line is the HTTP status, the rest the JSON body.
# A missing file answers 404 "Not Found". Like `gh api`, a non-2xx answer
# prints the body on stdout, "gh: <message> (HTTP <code>)" on stderr and exits 1.
[ "${1:-}" = api ] || { echo "stub gh: only 'gh api' is supported" >&2; exit 2; }
shift; method=GET; path=; input=0
while [ $# -gt 0 ]; do
  case $1 in
    -X|--method) method=$2; shift 2 ;;
    --input) input=1; shift 2 ;;
    -*) shift ;;
    *) path=$1; shift ;;
  esac
done
body=; [ "$input" = 1 ] && body=$(cat)
printf '%s %s %s\n' "$method" "$path" "$body" >> "$STUB_GH_DIR/calls"
f="$STUB_GH_DIR/$method-${path##*/}"
if [ ! -f "$f" ]; then
  echo '{"message":"Not Found"}'; echo "gh: Not Found (HTTP 404)" >&2; exit 1
fi
code=$(head -n 1 "$f"); tail -n +2 "$f"
case $code in
  2*) exit 0 ;;
  *) echo "gh: $(tail -n +2 "$f" | jq -r '.message // "error"') (HTTP $code)" >&2; exit 1 ;;
esac
