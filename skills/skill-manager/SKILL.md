---
name: skill-manager
description: Install and update agent skills from GitHub repos into ~/.agents/skills/. Use when the user wants to install skills from a repo, update installed skills, or check for available updates. Triggered by "install-skills <repo>", "update-skills [repo]", "install skills from", "add skills from", "update my skills", or "check for skill updates".
compatibility: Requires gh (GitHub CLI >= v2.90.0), git, python3, and optionally npx.
---

# Skill Manager

Manage agent skills installation and updates from GitHub repos into `~/.agents/skills/`.

## Commands

- **`install-skills <repo>`** — install skills from a GitHub repo (e.g., `install-skills obra/superpowers`)
- **`update-skills [repo]`** — check for and apply updates; omit repo to check all registered skills

Natural language: "install skills from X", "add skills from X", "update my skills", "check for skill updates".

## On Every Invocation

Before any other action, run the update check:

```bash
bash ~/.agents/skills/skill-manager/scripts/check-updates.sh
```

Surface the output to the user if non-empty. Then proceed with the requested operation.

---

## Install Flow (`install-skills <repo>`)

### Step 1: Detect Current Platform

```bash
PLATFORM=$(bash ~/.agents/skills/skill-manager/scripts/detect-platform.sh)
```

Confirm with the user: "I detected you're running on **[platform]**. Is that correct?"

Ask: "Would you like to install for additional platforms too?"

### Step 2: Check If Already Registered

```bash
ENTRIES=$(bash ~/.agents/skills/skill-manager/scripts/registry.sh read)
```

If an entry with matching `repo` exists in the JSON array, show the currently installed skills and ask: "Would you like to add more skills or reinstall existing ones?" Adjust the remaining steps accordingly.

### Step 3: Inspect the Repo

Fetch the repo tree:

```bash
gh api "repos/{owner}/{repo}/git/trees/HEAD?recursive=1" --jq '[.tree[].path]'
```

Check for install signals in priority order. Multiple signals may be present — offer all applicable options.

**a. Platform instruction files:** `AGENTS.md`, `GEMINI.md`, `CLAUDE.md`, `.opencode/INSTALL.md`

If found for any target platform(s), read the file:

```bash
gh api "repos/{owner}/{repo}/contents/{file}" --jq '.content' | base64 -d
```

Offer to follow the platform-native install instructions (e.g., `/plugin install` for Claude Code). Tell the user: "Platform-native installs are managed and updated by the platform directly — skill-manager won't track those." The user may choose platform-native, `~/.agents/skills/`, or both.

**b. `skills/*/SKILL.md` paths present** → use `gh skill install`

**c. `.claude-plugin/marketplace.json` or similar present** → use `npx skills add`

**d. `README.md` present** → fetch it, show the install section, ask the user how to proceed

**e. Nothing found** → tell the user no standard install method was detected; work with them to find a solution; record whatever is agreed on as `install_tool: manual`

### Step 4: Bulk vs Selective

Extract available skill names from tree paths matching `skills/*/SKILL.md`. Ask: "Install all, or pick specific ones?"

### Step 5: Run the Install

**`gh skill`:**
```bash
gh skill install {owner}/{repo} {skill-name} --scope user
```

**`npx skills`:**
```bash
npx skills add {owner}/{repo} --skill {skill-name} -a universal -y
```

For platform-native installs: run or surface the command. Do not write a registry entry.

### Step 6: Update the Registry

```bash
SHA=$(gh api "repos/{owner}/{repo}/commits/HEAD" --jq '.sha')
ENTRY=$(python3 -c "
import json, sys, subprocess
sha = subprocess.check_output([\"gh\", \"api\", \"repos/{owner}/{repo}/commits/HEAD\", \"--jq\", \".sha\"]).decode().strip()
print(json.dumps({
    'repo': '{owner}/{repo}',
    'install_tool': '{gh|npx|manual}',
    'install_cmd': '{exact command run}',
    'skills_installed': ['{skill-name}'],
    'sha': sha,
    'installed_at': '{YYYY-MM-DD}'
}))
")
bash ~/.agents/skills/skill-manager/scripts/registry.sh write "$ENTRY"
```

---

## Update Flow (`update-skills [repo]`)

### Step 1: Run Update Check

```bash
bash ~/.agents/skills/skill-manager/scripts/check-updates.sh
```

The script covers all three paths:
- `gh`-managed: `gh skill update --dry-run`
- `npx`/`manual`: HEAD SHA comparison against registry
- Unregistered skill dirs: listed for optional registration

### Step 2: Present and Apply

If nothing to report, tell the user everything is up to date.

Otherwise ask: "Update all, pick specific ones, or skip?"

**`gh`-managed:**
```bash
gh skill update {skill-name}
```

**`npx`-managed:**
Re-run the recorded `install_cmd`.

**`manual`:** Show the recorded `install_cmd` and the latest release if accessible:
```bash
gh api "repos/{owner}/{repo}/releases/latest" --jq '{tag: .tag_name, notes: .body}'
```
Work with the user to determine the right update action.

### Step 3: Refresh Registry SHA

After a successful update:
```bash
SHA=$(gh api "repos/{owner}/{repo}/commits/HEAD" --jq '.sha')
bash ~/.agents/skills/skill-manager/scripts/registry.sh write \
  "$(python3 -c "import json; print(json.dumps({'repo': '{owner}/{repo}', 'sha': '$SHA'}))")"
```

### Step 4: Retroactive Registration (if unregistered skills reported)

For each unregistered skill the user wants to register:

1. Ask: "What is the source repo? (e.g., `obra/superpowers`)"
2. Ask: "How was it installed? (`gh`, `npx`, or `manual`)"
3. Ask: "What was the install command?"
4. Fetch SHA and write the entry:

```bash
SHA=$(gh api "repos/{owner}/{repo}/commits/HEAD" --jq '.sha')
bash ~/.agents/skills/skill-manager/scripts/registry.sh write \
  "$(python3 -c "import json; print(json.dumps({
    'repo': '{owner}/{repo}',
    'install_tool': '{tool}',
    'install_cmd': '{command}',
    'skills_installed': ['{skill-name}'],
    'sha': '$SHA',
    'installed_at': '{YYYY-MM-DD}'
  }))")"
```
