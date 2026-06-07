#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}/.registry.yaml"
SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
CMD="${1:-}"
ARG="${2:-}"

if [[ -z "$CMD" ]]; then
  echo "registry.sh: command required (read|write|list-unregistered)" >&2
  exit 1
fi

python3 - "$CMD" "$ARG" "$REGISTRY" "$SKILLS_DIR" << 'PYEOF'
import sys, os, json

cmd = sys.argv[1]
arg = sys.argv[2]
registry_file = sys.argv[3]
skills_dir = sys.argv[4]

# Registry is stored as JSON (a strict subset of YAML) for stdlib compatibility.
HEADER = "# Managed by skill-manager. Edit with care.\n"

def load_registry():
    if not os.path.exists(registry_file):
        return {"entries": []}
    with open(registry_file) as f:
        content = f.read()
    # Strip only the known header line, not arbitrary lines starting with #
    if content.startswith("# Managed by skill-manager"):
        newline = content.find("\n")
        content = content[newline + 1:] if newline != -1 else ""
    if not content.strip():
        return {"entries": []}
    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        print(f"registry: could not parse {registry_file}: {e}", file=sys.stderr)
        sys.exit(1)

def save_registry(data):
    parent = os.path.dirname(registry_file)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(registry_file, "w") as f:
        f.write(HEADER)
        json.dump(data, f, indent=2)
        f.write("\n")

def frontmatter_has_gh_metadata(path):
    """Check only the YAML frontmatter block for the github-repo: key."""
    try:
        with open(path) as f:
            content = f.read()
    except OSError:
        return False
    if not content.startswith("---"):
        return False
    end = content.find("---", 3)
    if end == -1:
        return False
    frontmatter = content[3:end]
    return "github-repo:" in frontmatter

if cmd == "read":
    data = load_registry()
    print(json.dumps(data.get("entries", [])))

elif cmd == "write":
    try:
        new_entry = json.loads(arg)
    except json.JSONDecodeError as e:
        print(f"registry write: invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
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
        if frontmatter_has_gh_metadata(os.path.join(path, "SKILL.md")):
            continue
        print(item)

else:
    print(f"registry: unknown command: {cmd!r} (expected read|write|list-unregistered)", file=sys.stderr)
    sys.exit(1)
PYEOF
