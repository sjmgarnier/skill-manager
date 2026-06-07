#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}/.registry.yaml"
SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CMD="${1:-}"
ARG="${2:-}"

python3 - "$CMD" "$ARG" "$REGISTRY" "$SKILLS_DIR" << 'PYEOF'
import sys, os, json

cmd = sys.argv[1]
arg = sys.argv[2]
registry_file = sys.argv[3]
skills_dir = sys.argv[4]

# Registry is stored as JSON (a strict subset of YAML) for stdlib compatibility.
# A leading comment line is stripped on read and re-added on write.
HEADER = "# Managed by skill-manager. Edit with care.\n"

def load_registry():
    if not os.path.exists(registry_file):
        return {"entries": []}
    with open(registry_file) as f:
        content = f.read()
    # Strip leading comment lines before JSON parsing
    lines = [l for l in content.splitlines() if not l.startswith("#")]
    return json.loads("\n".join(lines)) if any(l.strip() for l in lines) else {"entries": []}

def save_registry(data):
    os.makedirs(os.path.dirname(registry_file), exist_ok=True)
    with open(registry_file, "w") as f:
        f.write(HEADER)
        json.dump(data, f, indent=2)
        f.write("\n")

if cmd == "read":
    data = load_registry()
    print(json.dumps(data.get("entries", [])))

elif cmd == "write":
    new_entry = json.loads(arg)
    data = load_registry()
    entries = data.get("entries", [])
    updated = False
    for i, entry in enumerate(entries):
        if entry.get("repo") == new_entry.get("repo"):
            entries[i].update(new_entry)
            updated = True
            break
    if not updated:
        entries.append(new_entry)
    data["entries"] = entries
    save_registry(data)

elif cmd == "list-unregistered":
    data = load_registry()
    registered = {s for e in data.get("entries", []) for s in e.get("skills_installed", [])}
    if not os.path.isdir(skills_dir):
        sys.exit(0)
    for item in sorted(os.listdir(skills_dir)):
        if item.startswith("."):
            continue
        path = os.path.join(skills_dir, item)
        if not os.path.isdir(path):
            continue
        if item in registered:
            continue
        skill_md = os.path.join(path, "SKILL.md")
        if os.path.exists(skill_md):
            with open(skill_md) as f:
                if "github-repo:" in f.read():
                    continue
        print(item)
PYEOF
