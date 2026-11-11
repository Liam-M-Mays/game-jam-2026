#!/usr/bin/env python3
"""Project checks for CI. Standard library only.

  python3 .github/ci/checks.py repo                 file and reference checks, no Godot needed
  python3 .github/ci/checks.py repo --update        rewrite the repo part of known-problems.txt
  python3 .github/ci/checks.py logs DIR             read the Godot logs written by run_godot_checks.sh
  python3 .github/ci/checks.py logs DIR --update    rewrite the Godot part of known-problems.txt
  python3 .github/ci/checks.py tests DIR            read only the test log written by run_tests.sh

A problem listed in known-problems.txt is tolerated. A new problem fails the run.
A listed problem that no longer happens also fails the run, so the list can only shrink.
"""
import os
import re
import subprocess
import sys

KNOWN_PATH = ".github/ci/known-problems.txt"
ART_DIR = "ART/"
SCRIPT_EXT = (".gd", ".gdshader")
IMPORT_EXT = (".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp", ".wav", ".ogg", ".mp3", ".ttf", ".otf", ".woff", ".woff2")
REF_EXT = (".tscn", ".tres", ".gd", ".gdshader", ".godot")
MARKER_EXT = (".tscn", ".tres", ".gd", ".gdshader", ".godot", ".cfg", ".import")
WARN_MB, FAIL_MB = 5, 20
REPO_RULES = ("missing-sidecar", "orphan-sidecar", "sidecar-in-ignored-folder", "broken-ref", "cache-ref", "art-boundary", "sim-boundary", "conflict-marker", "large-file", "codeowners")
TEST_RULES = ("test-failed",)
LOG_RULES = ("import-error", "load-error", "boot-error") + TEST_RULES
# New code lives in these folders. A script in a sim/ folder under one of them is simulation code.
NEW_CODE_DIRS = ("game/", "addons/")
# What simulation code must not name, and the word shown in the report.
SIM_BANNED = (
    ("Camera2D", r"\bCamera2D\b"),
    ("Input.", r"\bInput\."),
    ("get_viewport", r"\bget_viewport\b"),
    ("Sprite2D", r"\bSprite2D\b"),
    ("create_tween", r"\bcreate_tween\b"),
    ("the audio service", r"\b(?:Audio|VillageAudio|Music)\.|\bAudioServer\b|\bAudioStreamPlayer"),
)
NOISE = ("leaked at exit", "still in use at exit", "RID allocations of type", "ObjectDB instances were leaked")

RULE_HELP = {
    "missing-sidecar": "Godot writes a .uid file next to every script and a .import file next to every asset. Open the project in Godot once and commit the new file too.",
    "orphan-sidecar": "This .uid or .import file has no source file any more. Delete it.",
    "sidecar-in-ignored-folder": "This folder has a .gdignore file, so Godot does not import it. Delete the .import or .uid file.",
    "broken-ref": "This file points at a res:// path that does not exist. Fix the path or delete the reference.",
    "cache-ref": "This file points into res://.godot/, Godot's private cache that is not in git. Point it at the source file instead.",
    "art-boundary": "Game files must not use anything under ART/. Move the file into assets/ and update the reference.",
    "sim-boundary": "A script in a sim/ folder is simulation code and must run with no window. It cannot name the camera, the mouse or keyboard, the viewport, a sprite, a tween or the audio service. Move that part into a view/ file, or send an event. See game/README.md.",
    "conflict-marker": "A git merge conflict marker was committed. Resolve the conflict.",
    "large-file": "Files over %d MB are refused. Compress it, or talk to the team about Git LFS." % FAIL_MB,
    "codeowners": ".github/CODEOWNERS must exist and have a '*' line.",
    "import-error": "Godot reported an error while importing the project.",
    "load-error": "Godot reported an error while loading this file.",
    "boot-error": "A script error happened while this scene was running.",
    "test-failed": "A test failed. Run it yourself with: bash .github/ci/run_tests.sh. See docs/testing.md.",
}


def git_files():
    out = subprocess.check_output(["git", "ls-files", "-z"])
    return [f for f in out.decode("utf-8", "replace").split("\0") if f]


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


class Report:
    def __init__(self):
        self.problems = {}
        self.warnings = []

    def add(self, rule, key, file=None, line=None):
        self.problems.setdefault((rule, key), (file, line))

    def warn(self, text):
        self.warnings.append(text)


def code_of(line):
    """The line without its comment. A '#' inside a string is kept."""
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote and line[i - 1] != "\\":
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#":
            return line[:i]
    return line


def is_sim_file(path):
    return path.endswith(".gd") and path.startswith(NEW_CODE_DIRS) and "/sim/" in path


def repo_checks(report):
    files = git_files()
    fileset = set(files)
    ignored = {os.path.dirname(f) for f in files if os.path.basename(f) == ".gdignore"}

    def in_ignored(path):
        parts = path.split("/")[:-1]
        if any(p.startswith(".") for p in parts):
            return True
        return any(path == d or path.startswith(d + "/") for d in ignored if d)

    for f in files:
        if f.endswith(".uid") or f.endswith(".import"):
            source = f.rsplit(".", 1)[0]
            if in_ignored(f):
                if not any(p.startswith(".") for p in f.split("/")[:-1]):
                    report.add("sidecar-in-ignored-folder", f, f)
            elif source not in fileset:
                report.add("orphan-sidecar", f, f)
            continue
        if in_ignored(f):
            continue
        # ART/ is source art that gets uploaded without opening Godot, so its
        # files do not have to carry a sidecar. See docs/art-folders.md.
        if f.startswith(ART_DIR):
            continue
        if f.endswith(SCRIPT_EXT) and f + ".uid" not in fileset:
            report.add("missing-sidecar", f + ".uid", f)
        if f.lower().endswith(IMPORT_EXT) and f + ".import" not in fileset:
            report.add("missing-sidecar", f + ".import", f)

    uid_to_path = {}
    for f in files:
        try:
            if f.endswith(".uid"):
                uid_to_path.setdefault(read(f).strip(), f[:-4])
            elif f.endswith(".import"):
                m = re.search(r'^uid="(uid://[^"]+)"', read(f), re.M)
                if m:
                    uid_to_path.setdefault(m.group(1), f[:-7])
            elif f.endswith((".tscn", ".tres")):
                with open(f, encoding="utf-8", errors="replace") as fh:
                    m = re.search(r'uid="(uid://[^"]+)"', fh.readline())
                if m:
                    uid_to_path.setdefault(m.group(1), f)
        except OSError:
            pass

    for f in files:
        if in_ignored(f) or not f.endswith(REF_EXT):
            continue
        targets = set()
        for number, line in enumerate(read(f).splitlines(), 1):
            for m in re.finditer(r'res://([^"\'\n]*)', line):
                path = m.group(1).strip().rstrip("/")
                if not path:
                    continue
                if path.startswith(".godot/"):
                    report.add("cache-ref", "%s -> res://%s" % (f, path), f, number)
                    continue
                if not os.path.exists(path):
                    report.add("broken-ref", "%s -> res://%s" % (f, path), f, number)
                    continue
                targets.add((path, number))
            for m in re.finditer(r"uid://[a-z0-9]+", line):
                path = uid_to_path.get(m.group(0))
                if path:
                    targets.add((path, number))
        if not f.startswith(ART_DIR):
            seen = set()
            for path, number in sorted(targets, key=lambda t: t[1]):
                if path.startswith(ART_DIR) and path not in seen:
                    seen.add(path)
                    report.add("art-boundary", "%s -> res://%s" % (f, path), f, number)

    for f in files:
        if not is_sim_file(f):
            continue
        for number, line in enumerate(read(f).splitlines(), 1):
            code = code_of(line)
            for name, pattern in SIM_BANNED:
                if re.search(pattern, code):
                    report.add("sim-boundary", "%s names %s" % (f, name), f, number)

    for f in files:
        if f.endswith(MARKER_EXT) and not any(p.startswith(".") for p in f.split("/")[:-1]):
            for number, line in enumerate(read(f).splitlines(), 1):
                if line.startswith("<<<<<<< ") or line.startswith(">>>>>>> ") or line == "=======":
                    report.add("conflict-marker", f, f, number)
                    break
        try:
            size = os.path.getsize(f) / 1048576.0
        except OSError:
            continue
        if size > FAIL_MB:
            report.add("large-file", f, f)
        elif size > WARN_MB:
            report.warn("%s is %.1f MB. Files over %d MB are refused." % (f, size, FAIL_MB))

    owners = ".github/CODEOWNERS"
    if owners not in fileset or not re.search(r"^\*\s+@", read(owners), re.M):
        report.add("codeowners", owners, owners)


def lines_of(log_dir, name):
    path = os.path.join(log_dir, name)
    if not os.path.exists(path):
        return None
    return [re.sub(r"\x1b\[[0-9;]*m", "", l).rstrip() for l in read(path).splitlines()]


def is_error(line):
    if any(n in line for n in NOISE):
        return False
    return line.startswith(("ERROR:", "SCRIPT ERROR:")) or "Parse Error" in line


def test_checks(report, log_dir):
    lines = lines_of(log_dir, "tests.log")
    if lines is None:
        report.add("test-failed", "tests.log is missing")
        return
    current, done = "(startup)", False
    for line in lines:
        if line.startswith("TEST RUN "):
            current = line[len("TEST RUN "):]
        elif line.startswith("TEST FAIL "):
            what = line[len("TEST FAIL "):].replace("res://", "")
            file = what.split("::")[0].split(" | ")[0]
            report.add("test-failed", what[:240], file if os.path.exists(file) else None)
        elif line.startswith("TESTS DONE"):
            done = True
        elif line.startswith("SCRIPT ERROR:") and not done:
            name = current.replace("res://", "")
            file = name.split("::")[0]
            report.add("test-failed", "%s | script error: %s" % (name, line[len("SCRIPT ERROR:"):].strip()[:160]), file if os.path.exists(file) else None)
        elif is_error(line) and not done:
            report.warn("While running the tests, the engine logged: %s" % line[:200])
    if not done:
        report.add("test-failed", "the test run did not finish")


def log_checks(report, log_dir):
    def lines_of_log(name):
        return lines_of(log_dir, name)

    lines = lines_of_log("import.log")
    if lines is None:
        report.add("import-error", "import.log is missing")
    else:
        for line in lines:
            if is_error(line):
                report.add("import-error", line[:200])

    lines = lines_of_log("load.log")
    if lines is None:
        report.add("load-error", "load.log is missing")
    else:
        current, done = "(startup)", False
        for line in lines:
            if line.startswith("LOADCHECK FILE "):
                current = line[len("LOADCHECK FILE "):].replace("res://", "")
            elif line.startswith("LOADCHECK FAIL "):
                report.add("load-error", current, current)
            elif line.startswith("LOADCHECK DONE"):
                done, current = True, "(shutdown)"
            elif is_error(line) and current != "(shutdown)":
                report.add("load-error", current, current if os.path.exists(current) else None)
        if not done:
            report.add("load-error", "the load check did not finish")

    for name in sorted(os.listdir(log_dir)):
        if not (name.startswith("boot-") and name.endswith(".log")):
            continue
        scene = name[len("boot-"):-len(".log")]
        status_path = os.path.join(log_dir, name[:-4] + ".exit")
        if os.path.exists(status_path) and read(status_path).strip() not in ("0", ""):
            report.add("boot-error", "%s | Godot exited with code %s" % (scene, read(status_path).strip()))
        for line in lines_of_log(name):
            if line.startswith("SCRIPT ERROR:"):
                report.add("boot-error", "%s | %s" % (scene, line[len("SCRIPT ERROR:"):].strip()[:160]))
            elif is_error(line):
                report.warn("While running %s, the engine logged: %s" % (scene, line[:200]))

    test_checks(report, log_dir)


def load_known():
    known = set()
    if os.path.exists(KNOWN_PATH):
        for line in read(KNOWN_PATH).splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                rule, _, key = line.partition(" ")
                known.add((rule, key.strip()))
    return known


def write_known(known):
    header = [
        "# Known problems that CI tolerates for now.",
        "# One per line: the rule name, a space, then what it found.",
        "# When you fix one, delete its line in the same pull request. CI tells you which.",
        "# Do not add lines by hand to get a pull request through. Fix the problem instead,",
        "# or agree with the team that it can wait and say so in the pull request.",
        "",
    ]
    body = ["%s %s" % (rule, key) for rule, key in sorted(known)]
    with open(KNOWN_PATH, "w", encoding="utf-8") as fh:
        fh.write("\n".join(header + body) + "\n")


def finish(report, rules, update):
    known = load_known()
    mine = {k for k in known if k[0] in rules}
    found = set(report.problems)
    if update:
        write_known((known - mine) | found)
        print("Wrote %s with %d entries for: %s" % (KNOWN_PATH, len(found), ", ".join(rules)))
        return 0
    new = sorted(found - mine)
    stale = sorted(mine - found)
    in_actions = os.environ.get("GITHUB_ACTIONS") == "true"
    summary = []

    for text in report.warnings:
        print("warning: " + text)
        if in_actions:
            print("::warning::" + text)

    if new:
        print("\nNEW PROBLEMS (%d)" % len(new))
        summary.append("### New problems (%d)\n" % len(new))
        last = None
        for rule, key in new:
            if rule != last:
                print("\n[%s] %s" % (rule, RULE_HELP.get(rule, "")))
                summary.append("\n**%s**: %s\n" % (rule, RULE_HELP.get(rule, "")))
                last = rule
            file, line = report.problems[(rule, key)]
            print("  - " + key)
            summary.append("- `%s`" % key)
            if in_actions:
                where = ("file=%s%s" % (file, ",line=%d" % line if line else "")) if file else ""
                print("::error %s::%s: %s" % (where, rule, key))
    if stale:
        print("\nFIXED, PLEASE UPDATE THE LIST (%d)" % len(stale))
        print("These lines are in %s but the problem is gone. Delete them:" % KNOWN_PATH)
        summary.append("\n### Fixed, please delete these lines from `%s` (%d)\n" % (KNOWN_PATH, len(stale)))
        for rule, key in stale:
            print("  - %s %s" % (rule, key))
            summary.append("- `%s %s`" % (rule, key))
        if in_actions:
            print("::error file=%s::%d fixed problem(s) are still listed. Delete their lines." % (KNOWN_PATH, len(stale)))

    tolerated = len(found & mine)
    verdict = "FAILED" if (new or stale) else "OK"
    line = "%s: %d new, %d fixed but still listed, %d known and tolerated, %d warnings" % (verdict, len(new), len(stale), tolerated, len(report.warnings))
    print("\n" + line)
    if in_actions and os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as fh:
            fh.write("## %s\n\n%s\n\n%s\n" % (" / ".join(rules[:1]) + " checks", line, "\n".join(summary)))
    return 1 if (new or stale) else 0


def main(argv):
    if len(argv) < 2 or argv[1] not in ("repo", "logs", "tests"):
        print(__doc__)
        return 2
    update = "--update" in argv
    args = [a for a in argv[2:] if a != "--update"]
    report = Report()
    if argv[1] == "repo":
        repo_checks(report)
        return finish(report, REPO_RULES, update)
    if not args:
        print("%s needs the folder that holds the Godot logs" % argv[1])
        return 2
    if argv[1] == "tests":
        test_checks(report, args[0])
        return finish(report, TEST_RULES, update)
    log_checks(report, args[0])
    return finish(report, LOG_RULES, update)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
