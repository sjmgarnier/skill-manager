#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

python3 - "$SCRIPTS_DIR" << 'PYEOF'
import subprocess, sys, os, json

scripts_dir = sys.argv[1]

def run(cmd):
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return r.stdout.strip()

entries_json = run(f"bash '{scripts_dir}/registry.sh' read")
entries = json.loads(entries_json)

updates = []
has_gh_entries = False

for entry in entries:
    repo = entry.get("repo", "")
    tool = entry.get("install_tool", "")
    recorded_sha = entry.get("sha", "")
    skills = entry.get("skills_installed", [repo])

    if tool == "gh":
        has_gh_entries = True
    else:
        current_sha = run(f"gh api 'repos/{repo}/commits/HEAD' --jq '.sha' 2>/dev/null")
        if current_sha and current_sha != recorded_sha:
            label = ", ".join(skills)
            updates.append(f"{label} ({repo}) — SHA changed")

if has_gh_entries:
    gh_out = run("gh skill update --dry-run 2>/dev/null")
    for line in gh_out.splitlines():
        if line.strip():
            updates.append(line.strip())

unregistered_out = run(f"bash '{scripts_dir}/registry.sh' list-unregistered")
unregistered = [s for s in unregistered_out.splitlines() if s.strip()]

if updates or unregistered:
    if updates:
        print("Skill updates available:")
        for u in updates:
            print(f"  ✓ {u}")
    if unregistered:
        if updates:
            print()
        print("Unregistered skills (no update tracking):")
        for s in unregistered:
            print(f"  ? {s} — would you like to register it?")
PYEOF
