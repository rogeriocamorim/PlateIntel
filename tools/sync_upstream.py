#!/usr/bin/env python3
"""Bring a new upstream release of UsefulPlatesAndTooltips into PlateIntel.

PlateIntel renames the addon, so `git merge upstream/main` would conflict on every file. This script does the
rename on both sides first, then a 3-way merge per file (git merge-file):

    base   = upstream at the commit recorded in docs/UPSTREAM.md, renamed
    ours   = this repo's addon files
    theirs = upstream at the commit you ask for (default: its HEAD), renamed

Usage (from the repo root):
    python tools/sync_upstream.py https://github.com/Ironship/UsefulPlatesAndTooltips            # report only
    python tools/sync_upstream.py <url-or-local-clone> --apply                                    # write into the repo
    python tools/sync_upstream.py <url-or-local-clone> --ref <commit> --apply

Files upstream did not change are left alone. A file changed on both sides is merged; conflicts are left as
<<<<<<< markers for you to resolve. Developer-only upstream files (CLAUDE.md, tools/, docs, the Retail .toc) are
skipped. After --apply, update docs/UPSTREAM.md and CHANGELOG.md.
"""
import argparse, os, re, subprocess, sys, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD, NEW = "UsefulPlatesAndTooltips", "PlateIntel"
# Saved-variable names keep the old name (settings would reset otherwise).
RENAME = re.compile(rb"UsefulPlatesAndTooltips(?!(_[A-Za-z]+)?DB\b)")
TEXT = (".lua", ".toc", ".xml")
SKIP_PREFIX = ("tools/", "docs/", ".github/")
SKIP_NAMES = {"CLAUDE.md", "AGENTS.md", "API.md", "README.md", "RETAIL.md", "CHANGELOG.md", "CREDITS.md",
              "PlateIntel_Mainline.toc"}
OURS_ONLY = ("README.md", "CREDITS.md", "CHANGELOG.md", ".gitignore", ".gitattributes", ".editorconfig", ".pkgmeta",
             ".luacheckrc", "Core/Integrations/", "Modules/DoTInfo/KillCheck.lua")


def run(*cmd, cwd=None, out=False):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True)
    if r.returncode and not out:
        sys.exit("command failed: %s\n%s" % (" ".join(cmd), r.stderr.decode("utf-8", "replace")))
    return r


def export(clone, ref, dest):
    os.makedirs(dest)
    arch = run("git", "archive", ref, cwd=clone).stdout
    subprocess.run(["tar", "-x", "-C", dest], input=arch, check=True)


def load(root):
    files = {}
    for folder, _, names in os.walk(root):
        for name in names:
            path = os.path.join(folder, name)
            rel = os.path.relpath(path, root).replace(os.sep, "/")
            if rel.startswith(".git/") or rel.startswith(SKIP_PREFIX) or rel in SKIP_NAMES:
                continue
            data = open(path, "rb").read()
            if rel.lower().endswith(TEXT):
                data = RENAME.sub(NEW.encode(), data.replace(b"\r\n", b"\n"))
            files[rel.replace(OLD, NEW)] = data
    return files


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("upstream", help="upstream git URL or a local clone")
    ap.add_argument("--ref", default="HEAD", help="upstream commit to merge (default HEAD)")
    ap.add_argument("--apply", action="store_true", help="write the merged files into this repo")
    args = ap.parse_args()

    text = open(os.path.join(REPO, "docs", "UPSTREAM.md"), encoding="utf-8").read()
    m = re.search(r"Last synced upstream commit:\s*`?([0-9a-f]{7,40})", text)
    if not m:
        sys.exit("docs/UPSTREAM.md has no 'Last synced upstream commit: <hash>' line")
    base_ref = m.group(1)

    work = tempfile.mkdtemp(prefix="plateintel-sync-")
    clone = args.upstream
    if "://" in clone:
        clone = os.path.join(work, "clone")
        run("git", "clone", "-q", args.upstream, clone)
    export(clone, base_ref, os.path.join(work, "base"))
    export(clone, args.ref, os.path.join(work, "head"))
    base, head, ours = load(work + "/base"), load(work + "/head"), load(REPO)
    ours = {k: v for k, v in ours.items() if not k.startswith(".git/")}

    report = {"updated": [], "merged": [], "conflict": [], "added": [], "removed upstream": []}
    for rel in sorted(set(base) | set(head)):
        b, h, o = base.get(rel), head.get(rel), ours.get(rel)
        if h == b or rel.startswith(OURS_ONLY):
            continue
        if h is None:
            report["removed upstream"].append(rel)
            continue
        if o is None and b is None:
            new, kind = h, "added"
        elif o is None or o == b:
            new, kind = h, "updated"
        elif o == h:
            continue
        elif not rel.lower().endswith(TEXT):
            report["conflict"].append(rel + " (binary)")
            continue
        else:
            tmp = os.path.join(work, "m")
            os.makedirs(tmp, exist_ok=True)
            for n, v in (("o", o), ("b", b or b""), ("h", h)):
                open(os.path.join(tmp, n), "wb").write(v)
            r = run("git", "merge-file", "-p", "-L", "ours", "-L", "base", "-L", "upstream",
                    os.path.join(tmp, "o"), os.path.join(tmp, "b"), os.path.join(tmp, "h"), out=True)
            new, kind = r.stdout, "merged" if r.returncode == 0 else "conflict"
            if kind == "conflict":
                report["conflict"].append("%s (%d conflicts)" % (rel, r.returncode))
        if kind != "conflict":
            report[kind].append(rel)
        if args.apply:
            dest = os.path.join(REPO, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            open(dest, "wb").write(new)
    for key, items in report.items():
        print("%s: %d" % (key, len(items)))
        for item in items:
            print("   ", item)
    print("\nbase %s -> %s" % (base_ref, args.ref), "(applied)" if args.apply else "(report only, use --apply)")
    print("Next: bump docs/UPSTREAM.md to the new upstream commit, add a CHANGELOG.md entry, check PlateIntel.toc"
          " lists every new file, then /reload in game.")


if __name__ == "__main__":
    main()
