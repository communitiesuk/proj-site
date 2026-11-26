#!/usr/bin/env bash
# Shared helpers for the site core. Source this file; it defines functions only.
#
# Functions:
#   yaml_get <file> <key>     Print the value of <key> from a restricted-YAML file.
#                             <key> is `name` for top level or `parent.child` for one
#                             level of nesting. Surrounding quotes are removed; an
#                             inline list `[a, b]` is printed as "a b". Prints nothing
#                             (exit 0) when the key is absent. Comments (` # ...`) are
#                             ignored.
#   iso_week <YYYY-MM-DD>     Print the ISO week-numbering year and week, `%G-W%V`
#                             (e.g. 2026-W01). Works with GNU and BSD date.
#   frontmatter_get <file> <key>
#                             Print a top-level scalar from a Markdown file's YAML
#                             front matter (between the first two `---` lines).
#   link_github <repository> <project-dir>
#                             Copy Markdown from stdin to stdout, linking GitHub
#                             references in the body to https://github.com/<repository>:
#                               #N (N not starting with 0, not after a letter, digit,
#                                 `_` or `&`, not followed by a letter or digit)
#                                 -> [#N](.../issues/N)
#                               a path under docs/ or plans/ that exists at HEAD in
#                                 <project-dir>, not after a letter, digit, `/`, `.`,
#                                 `-` or `_`, not followed by a letter, digit or `/`
#                                 -> [path](.../blob/HEAD/path); absent paths stay text
#                               a 7-12 character lower-case hex string standing alone
#                                 that resolves with `git rev-parse --verify <hex>^{commit}`
#                                 in <project-dir> -> [hex](.../commit/hex)
#                             Left unchanged: the front matter (a leading `---` block),
#                             fenced code blocks, code spans, existing Markdown links,
#                             URLs and HTML tags. With an empty <repository> the input
#                             is copied unchanged. Needs python3 and git.

_strip_value() { # strip comment, whitespace and surrounding quotes from stdin
  sed -e 's/[[:space:]]#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
      -e 's/^"\(.*\)"$/\1/' -e "s/^'\\(.*\\)'\$/\\1/"
}

yaml_get() {
  local file=$1 key=$2 parent= child=$2
  case $key in *.*) parent=${key%%.*}; child=${key#*.};; esac
  [ -f "$file" ] || return 0
  local raw
  raw=$(awk -v parent="$parent" -v child="$child" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    {
      indent = match($0, /[^ ]/) - 1
      line = substr($0, indent + 1)
      k = line; sub(/:.*/, "", k)
      v = line; if (index(v, ":")) { sub(/^[^:]*:/, "", v) } else { v = "" }
      if (indent == 0) {
        cur = k
        if (parent == "" && k == child) { print v; exit }
      } else if (parent != "" && cur == parent && k == child) { print v; exit }
    }' "$file" | _strip_value)
  case $raw in
    \[*\]) raw=${raw#[}; raw=${raw%]}
           printf '%s\n' "$raw" | tr ',' '\n' | _strip_value | paste -sd ' ' - ;;
    *) printf '%s\n' "$raw" | sed '/^$/d' ;;
  esac
}

iso_week() {
  date -u -d "$1" +%G-W%V 2>/dev/null || date -u -j -f %F "$1" +%G-W%V
}

frontmatter_get() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 { k = $0; sub(/:.*/, "", k); if (k == key) { v = $0; sub(/^[^:]*:/, "", v); print v; exit } }
  ' "$1" | _strip_value
}

link_github() {
  if [ -z "$1" ]; then cat; return; fi
  python3 -c "$_LINK_GITHUB_PY" "$1" "$2"
}

_LINK_GITHUB_PY='
import re, subprocess, sys
repo, project = sys.argv[1], sys.argv[2]
base = "https://github.com/" + repo
cache = {}
def git_ok(*args):
    if args not in cache:
        cache[args] = subprocess.run(["git", "-C", project] + list(args),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    return cache[args]
# Protected spans, left exactly as written.
PROTECT = re.compile(r"(`+).*?\1|!?\[[^\]]*\]\([^)]*\)|<[^>]+>|https?://\S+")
REF = re.compile(
    r"(?<![A-Za-z0-9_&])#([1-9][0-9]*)(?![A-Za-z0-9])"
    r"|(?<![A-Za-z0-9/._-])((?:docs|plans)/[A-Za-z0-9._/-]*[A-Za-z0-9_])(?![A-Za-z0-9/])"
    r"|(?<![A-Za-z0-9])([0-9a-f]{7,12})(?![A-Za-z0-9])")
def link(m):
    issue, path, sha = m.group(1), m.group(2), m.group(3)
    if issue:
        return "[#%s](%s/issues/%s)" % (issue, base, issue)
    if path:
        if git_ok("cat-file", "-e", "HEAD:" + path):
            return "[%s](%s/blob/HEAD/%s)" % (path, base, path)
        return path
    if git_ok("rev-parse", "--verify", "-q", sha + "^{commit}"):
        return "[%s](%s/commit/%s)" % (sha, base, sha)
    return sha
def text(line):
    out, pos = [], 0
    for m in PROTECT.finditer(line):
        out.append(REF.sub(link, line[pos:m.start()])); out.append(m.group(0)); pos = m.end()
    out.append(REF.sub(link, line[pos:]))
    return "".join(out)
lines = sys.stdin.read().split("\n")
i, fence = 0, None
if lines and lines[0] == "---":
    i = 1
    while i < len(lines) and lines[i] != "---":
        i += 1
    i += 1
out = lines[:i]
for line in lines[i:]:
    f = re.match(r" {0,3}(`{3,}|~{3,})", line)
    if fence:
        if f and f.group(1)[0] == fence[0] and len(f.group(1)) >= len(fence):
            fence = None
        out.append(line)
    elif f:
        fence = f.group(1); out.append(line)
    else:
        out.append(text(line))
sys.stdout.write("\n".join(out))
'
