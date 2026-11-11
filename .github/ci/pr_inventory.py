#!/usr/bin/env python3
"""Counts what a pull request holds, as Markdown for its description. Standard library only.

  python3 .github/ci/pr_inventory.py                    compare this branch with origin/rework
  python3 .github/ci/pr_inventory.py --base origin/master

The point is the line count of CODE. Git's own count also includes scenes, docs and the
sidecar files Godot writes, which say little about how much there is to review.
A code line is a line in a script or shader that is not blank and not only a comment.
"""
import re
import subprocess
import sys

ART_EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp", ".aseprite", ".wav", ".ogg", ".mp3", ".ttf", ".otf")
# Kinds whose lines are counted as code, with the marker that starts a comment line.
CODE_KINDS = {"Game scripts": "#", "Dev tool and demo scripts": "#", "Test scripts": "#", "Shaders": "//", "CI scripts (.py, .sh)": "#"}
ORDER = ("Game scripts", "Dev tool and demo scripts", "Test scripts", "Shaders", "CI scripts (.py, .sh)", "Scenes (.tscn)", "Resources (.tres)",
         "Art and audio", "Project settings", "Docs", "CI and tooling", "Other")


def git(*args):
    return subprocess.check_output(["git", *args]).decode("utf-8", "replace")


def kind_of(path):
    name = path.rsplit("/", 1)[-1]
    if path.endswith((".uid", ".import")):
        return "sidecar"
    if path.startswith((".github/", ".claude/")):
        return "CI scripts (.py, .sh)" if path.endswith((".py", ".sh")) else "CI and tooling"
    if path.endswith(".gd"):
        if name.startswith("test_") or "/tests/" in path or "/test_runner/" in path:
            return "Test scripts"
        if path.startswith(("game/dev/", "assets/Scripts/Dev/")):
            return "Dev tool and demo scripts"
        return "Game scripts"
    if path.endswith((".gdshader", ".gdshaderinc")):
        return "Shaders"
    if path.endswith(".tscn"):
        return "Scenes (.tscn)"
    if path.endswith(".tres"):
        return "Resources (.tres)"
    if path.lower().endswith(ART_EXT):
        return "Art and audio"
    if path in ("project.godot", "export_presets.cfg"):
        return "Project settings"
    if path.endswith(".md"):
        return "Docs"
    return "Other"


def code_lines(base, path, marker):
    """Added and removed code lines of one file: not blank, not only a comment."""
    added = removed = 0
    for line in git("diff", "-U0", "--no-color", base + "...HEAD", "--", path).splitlines():
        if line.startswith(("+++", "---")) or not line.startswith(("+", "-")):
            continue
        text = line[1:].strip()
        if not text or text.startswith(marker):
            continue
        if line[0] == "+":
            added += 1
        else:
            removed += 1
    return added, removed


def main(argv):
    base = "origin/rework"
    if "--base" in argv:
        base = argv[argv.index("--base") + 1]
    counts = {k: {"new": 0, "changed": 0, "removed": 0, "added": 0, "deleted": 0} for k in ORDER}
    sidecars = 0
    for row in git("diff", "--name-status", "-M", base + "...HEAD").splitlines():
        parts = row.split("\t")
        status, path = parts[0][0], parts[-1]
        kind = kind_of(path)
        if kind == "sidecar":
            sidecars += 1
            continue
        counts[kind]["new" if status == "A" else "removed" if status == "D" else "changed"] += 1
        if kind in CODE_KINDS and status != "D":
            added, deleted = code_lines(base, path, CODE_KINDS[kind])
            counts[kind]["added"] += added
            counts[kind]["deleted"] += deleted
        elif kind in CODE_KINDS:
            old = parts[1] if len(parts) > 1 else path
            marker = CODE_KINDS[kind]
            body = git("show", "%s:%s" % (git("merge-base", base, "HEAD").strip(), old)).splitlines()
            counts[kind]["deleted"] += sum(1 for l in body if l.strip() and not l.strip().startswith(marker))

    stat = git("diff", "--shortstat", base + "...HEAD").strip()
    total_added = int((re.search(r"(\d+) insertion", stat) or [0, 0])[1])
    total_deleted = int((re.search(r"(\d+) deletion", stat) or [0, 0])[1])
    code_added = sum(counts[k]["added"] for k in CODE_KINDS)
    code_deleted = sum(counts[k]["deleted"] for k in CODE_KINDS)

    def n(value):
        return "{:,}".format(value)

    game = counts["Game scripts"]
    out = ["## Inventory", "",
           "**Game code: +%s lines** in %d new and %d changed scripts. Scenes: %d new, %d changed."
           % (n(game["added"]), game["new"], game["changed"], counts["Scenes (.tscn)"]["new"], counts["Scenes (.tscn)"]["changed"]),
           "", "| Lines of code | Added | Removed |", "| --- | --- | --- |"]
    for kind in CODE_KINDS:
        c = counts[kind]
        if c["new"] or c["changed"] or c["removed"]:
            out.append("| %s | %s | %s |" % (kind, n(c["added"]), n(c["deleted"])))
    out.append("| **All code** | **%s** | **%s** |" % (n(code_added), n(code_deleted)))
    out += ["", "| Files | New | Changed | Removed |", "| --- | --- | --- | --- |"]
    for kind in ORDER:
        c = counts[kind]
        if c["new"] or c["changed"] or c["removed"]:
            out.append("| %s | %d | %d | %d |" % (kind, c["new"], c["changed"], c["removed"]))
    out += ["",
            "- A code line is a line in a script or shader that is not blank and not only a comment.",
            "- Git counts +%s and -%s lines for this pull request. That also counts scenes, docs, comments and %d sidecar files (`.uid`, `.import`) that Godot writes."
            % (n(total_added), n(total_deleted), sidecars)]
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
