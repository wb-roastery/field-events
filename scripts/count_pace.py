#!/usr/bin/env python3
"""
Count Formula/Cask files added or modified since a given date, for a single
Homebrew tap. See README.md for the counting rules and why this expects a
full (non-shallow) clone.
"""
import argparse
import re
import subprocess
from pathlib import Path


def shallow_boundary_commits(repo_dir):
    """SHAs whose parent was truncated by --shallow-since. Their diff would
    show every file in the tree as added (no local parent to compare
    against), so they must be excluded rather than counted."""
    shallow_file = Path(repo_dir) / "shallow"
    if not shallow_file.exists():
        return set()
    return set(shallow_file.read_text().split())


def count_since_boundary(repo_dir, path_regex, since_date):
    pattern = re.compile(path_regex)
    boundary = shallow_boundary_commits(repo_dir)
    cmd = [
        "git", "-C", str(repo_dir), "log",
        "--first-parent", "--diff-merges=first-parent", "-M",
        f"--since={since_date}T00:00:00Z",
        "--name-status", "--pretty=format:@@%H",
    ]
    proc = subprocess.run(cmd, check=True, capture_output=True, text=True)

    count = 0
    skip_commit = False
    for line in proc.stdout.splitlines():
        if line.startswith("@@"):
            skip_commit = line[2:] in boundary
            continue
        if skip_commit or not line or "\t" not in line:
            continue
        parts = line.split("\t")
        status = parts[0]
        if status.startswith("R"):
            similarity = int(status[1:]) if len(status) > 1 else 100
            if similarity < 100 and pattern.match(parts[2]):
                count += 1
        elif status in ("A", "M") and pattern.match(parts[1]):
            count += 1
    return count


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo-dir", required=True, help="path to a full bare clone")
    ap.add_argument("--path-regex", required=True)
    ap.add_argument("--since", required=True, help="YYYY-MM-DD, UTC")
    args = ap.parse_args()
    print(count_since_boundary(args.repo_dir, args.path_regex, args.since))


if __name__ == "__main__":
    main()
