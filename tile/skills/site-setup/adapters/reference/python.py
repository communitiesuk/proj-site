#!/usr/bin/env python3
"""Reference-docs adapter for Python projects.

Usage: python <project-dir>

Finds ``*.py`` files under the project directory (skipping hidden
directories, ``site``, ``tests``, ``test_*.py``, ``venv``, ``.venv``,
``node_modules``, ``build``, ``dist`` and ``__pycache__``), parses them with
``ast`` (project code is never imported or executed) and prints a JSON array
of pages ``{"path", "title", "content"}`` sorted by path. A module yields a
page when it has a module docstring or a public top-level function or class.
Prints ``[]`` when there is no Python source. Files with syntax errors are
skipped with a warning on stderr.
"""
import ast
import json
import os
import sys

EXCLUDED_DIRS = {"site", "tests", "venv", ".venv", "node_modules", "build",
                 "dist", "__pycache__"}


def collect_files(root):
    """Return sorted module file paths under ``root`` that should be documented."""
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames
                       if not d.startswith(".") and d not in EXCLUDED_DIRS]
        for name in filenames:
            if name.endswith(".py") and not name.startswith("test_"):
                found.append(os.path.join(dirpath, name))
    return sorted(found)


def _render_args(a):
    """Render an ast.arguments node PEP 8 style (spaces around annotated defaults)."""
    def one(arg, default):
        text = arg.arg
        if arg.annotation is not None:
            text += ": " + ast.unparse(arg.annotation)
        if default is not None:
            text += (" = " if arg.annotation is not None else "=") + ast.unparse(default)
        return text

    pos = a.posonlyargs + a.args
    defaults = [None] * (len(pos) - len(a.defaults)) + list(a.defaults)
    out = [one(x, d) for x, d in zip(pos, defaults)]
    if a.posonlyargs:
        out.insert(len(a.posonlyargs), "/")
    if a.vararg:
        out.append("*" + one(a.vararg, None))
    elif a.kwonlyargs:
        out.append("*")
    out += [one(x, d) for x, d in zip(a.kwonlyargs, a.kw_defaults)]
    if a.kwarg:
        out.append("**" + one(a.kwarg, None))
    return ", ".join(out)


def _signature(node):
    """Render ``name(args) -> ret`` for a function node."""
    ret = " -> " + ast.unparse(node.returns) if node.returns else ""
    return "%s(%s)%s" % (node.name, _render_args(node.args), ret)


def _public(node):
    return not node.name.startswith("_")


def _doc(node):
    return ast.get_docstring(node) or ""


def render_module(source):
    """Return Markdown for ``source`` text, or None if it has nothing public.

    Raises SyntaxError if the source cannot be parsed.
    """
    tree = ast.parse(source)
    funcs = (ast.FunctionDef, ast.AsyncFunctionDef)
    parts = []
    mod_doc = _doc(tree)
    if mod_doc:
        parts.append(mod_doc)
    public = False
    for node in tree.body:
        if isinstance(node, funcs) and _public(node):
            public = True
            parts.append("## `%s`" % _signature(node))
            if _doc(node):
                parts.append(_doc(node))
        elif isinstance(node, ast.ClassDef) and _public(node):
            public = True
            parts.append("## class `%s`" % node.name)
            if _doc(node):
                parts.append(_doc(node))
            for item in node.body:
                if isinstance(item, funcs) and _public(item):
                    parts.append("### `%s`" % _signature(item))
                    if _doc(item):
                        parts.append(_doc(item))
    if not mod_doc and not public:
        return None
    return "\n\n".join(parts) + "\n"


def main(argv):
    """Entry point: print the JSON page array for ``argv[1]``; return exit code."""
    if len(argv) != 2 or not os.path.isdir(argv[1]):
        sys.stderr.write("usage: python <project-dir>\n")
        return 2
    root = argv[1]
    pages = []
    for path in collect_files(root):
        rel = os.path.relpath(path, root)
        try:
            with open(path, encoding="utf-8") as fh:
                content = render_module(fh.read())
        except (SyntaxError, ValueError, UnicodeDecodeError) as exc:
            sys.stderr.write("warning: skipping %s: %s\n" % (rel, exc))
            continue
        if content is None:
            continue
        mod = rel[:-3].replace(os.sep, "/")
        pages.append({"path": mod + ".md",
                      "title": mod.replace("/", "."),
                      "content": content})
    pages.sort(key=lambda p: p["path"])
    json.dump(pages, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
