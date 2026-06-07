#!/usr/bin/env bash
set -euo pipefail

# Resolve symlinks so this works when called via a symlink in ~/bin etc.
SCRIPTS_DIR="$(python3 -c "import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))" "$0")"

python3 - "$SCRIPTS_DIR" << 'PYEOF'
import subprocess, sys, os, json, shutil

scripts_dir = sys.argv[1]
registry_sh = os.path.join(scripts_dir, "registry.sh")

gh_available = shutil.which("gh") is not None
if not gh_available:
    print("warning: gh not found — update checks that require GitHub CLI will be skipped", file=sys.stderr)

def run(args, suppress_stderr=False):
    """Run a command (list form, no shell injection). Returns stdout or '' on failure."""
    try:
        r = subprocess.run(args, capture_output=True, text=True)
        if r.returncode != 0 and not suppress_stderr and r.stderr.strip():
            print(f"warning: {args[0]}: {r.stderr.strip()}", file=sys.stderr)
        return r.stdout.strip()
    except FileNotFoundError:
        if not suppress_stderr:
            print(f"warning: command not found: {args[0]}", file=sys.stderr)
        return ""

# Read registry
entries_json = run(["bash", registry_sh, "read"])
try:
    entries = json.loads(entries_json) if entries_json else []
except json.JSONDecodeError:
    print("warning: could not parse registry — run registry.sh read to diagnose", file=sys.stderr)
    entries = []

updates = []
has_gh_entries = False

for entry in entries:
    repo = entry.get("repo", "")
    tool = entry.get("install_tool", "")
    recorded_sha = entry.get("sha", "")
    skills = entry.get("skills_installed", [repo] if repo else [])

    if not repo:
        continue

    if tool == "gh":
        has_gh_entries = True
    elif tool in ("npx", "manual", ""):
        current_sha = run(["gh", "api", f"repos/{repo}/commits/HEAD", "--jq", ".sha"],
                          suppress_stderr=True)
        if current_sha and recorded_sha and current_sha != recorded_sha:
            label = ", ".join(skills) if skills else repo
            updates.append(f"{label} ({repo}) — SHA changed")
        elif current_sha and not recorded_sha:
            label = ", ".join(skills) if skills else repo
            updates.append(f"{label} ({repo}) — no baseline SHA recorded")
    else:
        print(f"warning: unknown install_tool {tool!r} for {repo}, skipping", file=sys.stderr)

if has_gh_entries:
    gh_out = run(["gh", "skill", "update", "--dry-run"], suppress_stderr=True)
    for line in gh_out.splitlines():
        line = line.strip()
        # Only surface lines that look like update notices (contain →), not errors or usage text
        if line and "→" in line:
            updates.append(line)

unregistered_out = run(["bash", registry_sh, "list-unregistered"])
unregistered = [s for s in unregistered_out.splitlines() if s.strip()]

if updates or unregistered:
    if updates:
        print("Skill updates available:")
        for u in updates:
            print(f"  ↑ {u}")
    if unregistered:
        if updates:
            print()
        print("Unregistered skills (no update tracking):")
        for s in unregistered:
            print(f"  ? {s} — would you like to register it?")
PYEOF
