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

First, locate the companion scripts. The install path varies by platform, so search all known locations:

```bash
for _dir in \
  "$HOME/.claude/skills/skill-manager/scripts" \
  "$HOME/.config/goose/skills/skill-manager/scripts" \
  "$HOME/.cursor/skills/skill-manager/scripts" \
  "$HOME/.gemini/skills/skill-manager/scripts" \
  "$HOME/.codeium/windsurf/skills/skill-manager/scripts" \
  "$HOME/.continue/skills/skill-manager/scripts" \
  "$HOME/.agents/skills/skill-manager/scripts" \
  "$HOME/.warp/skills/skill-manager/scripts"; do
  [ -d "$_dir" ] && SKILL_SCRIPTS="$_dir" && break
done
unset _dir
```

If `SKILL_SCRIPTS` is still unset after this loop, warn the user: "skill-manager scripts not found — the skill may not be installed correctly" and stop.

Then run the update check:

```bash
bash "$SKILL_SCRIPTS/check-updates.sh"
```

If it produces output, surface it to the user. If it fails or exits non-zero, show a brief warning ("could not check for updates — continuing") and proceed regardless.

---

## Install Flow (`install-skills <owner>/<repo>`)

### Step 1: Detect Current Platform

```bash
PLATFORM=$(bash "$SKILL_SCRIPTS/detect-platform.sh")
```

Confirm with the user: "I detected you're running on **$PLATFORM**. Is that correct?"

The `$PLATFORM` value maps directly to the `--agent` flag used by `gh skill install`:

| Detected platform | `--agent` value | Installs to (user scope) |
|---|---|---|
| `claude-code` | `claude-code` | `~/.claude/skills/` |
| `gemini-cli` | `gemini-cli` | `~/.gemini/skills/` |
| `goose` | `goose` | `~/.config/goose/skills/` |
| `codex` | `codex` | `~/.codex/skills/` |
| `cursor` | `cursor` | `~/.cursor/skills/` |
| `warp` | `warp` | `~/.agents/skills/` (shared dir) |
| `windsurf` | `windsurf` | `~/.codeium/windsurf/skills/` |
| `continue` | `continue` | `~/.continue/skills/` |
| `unknown` | ask the user — run `gh skill install --help` and show the supported agent list | varies |

Ask: "Would you like to install for additional platforms too?" If yes, collect all target platforms before proceeding.

### Step 2: Inspect the Repo

Fetch the HEAD commit SHA, then the full repo tree:

```bash
HEAD_SHA=$(gh api "repos/{owner}/{repo}/commits/HEAD" --jq '.sha')
TREE=$(gh api "repos/{owner}/{repo}/git/trees/${HEAD_SHA}?recursive=1" --jq '[.tree[].path]')
```

If this fails (repo not found, no network, not authenticated), surface the error and stop: "Could not access {owner}/{repo}. Check the repo name and run `gh auth status`."

Check for install signals in $TREE and the repo contents, in priority order. Multiple signals may be present — offer all applicable options.

**a. Platform instruction files:** `AGENTS.md`, `GEMINI.md`, `CLAUDE.md`, `.opencode/INSTALL.md`

If any are present for the target platform(s), fetch and display the relevant file:

```bash
gh api "repos/{owner}/{repo}/contents/{file}" --jq '.content' | \
  python3 -c "import base64,sys; sys.stdout.write(base64.b64decode(sys.stdin.read()).decode())"
```

Show the file contents to the user and ask: "This repo includes platform-specific install instructions for [platform]. Would you like me to follow them? (Platform-native installs are managed and updated by the platform directly — skill-manager won't track those.)"

Execute whatever commands the file specifies if the user agrees. The user may choose platform-native install, `~/.agents/skills/` install, or both.

**b. `skills/*/SKILL.md` paths present (single-level layout)** → use `gh skill install`

`gh skill install` only handles the single-level layout (`skills/<name>/SKILL.md`). If the tree contains paths matching `skills/*/*/SKILL.md` (category/name layout, e.g. `skills/github/pr-create/SKILL.md`) but no single-level paths, `gh skill install` cannot reach those skills — skip to signal **c** instead.

**c. `.claude-plugin/marketplace.json`, `skills/*/*/SKILL.md`, or similar present in $TREE** → use `npx skills add`

`npx skills add` handles both single-level and category/name layouts and supports `marketplace.json`-based repos. Prefer it whenever the repo uses nested skill directories.

**d. `README.md` present** → fetch it with:
```bash
gh api "repos/{owner}/{repo}/contents/README.md" --jq '.content' | \
  python3 -c "import base64,sys; sys.stdout.write(base64.b64decode(sys.stdin.read()).decode())"
```
Show the install section to the user and ask how to proceed.

**e. Nothing found** → tell the user no standard install method was detected; work with them to find a solution; record whatever is agreed on as `install_tool: manual`.

### Step 3: Check If Already Registered

```bash
ENTRIES=$(bash "$SKILL_SCRIPTS/registry.sh" read)
```

If an entry with matching `repo` exists in the JSON array, show the currently installed skills and ask: "Would you like to add more skills or reinstall existing ones?" Adjust the remaining steps accordingly.

### Step 4: Bulk vs Selective

Extract available skill names from `$TREE`:
- **Single-level:** paths matching `skills/*/SKILL.md` → skill name is the middle segment (e.g., `skills/brainstorming/SKILL.md` → `brainstorming`)
- **Category/name:** paths matching `skills/*/*/SKILL.md` → skill name is the innermost segment (e.g., `skills/github/pr-create/SKILL.md` → `pr-create`)

List the discovered skills and ask: "Install all, or pick specific ones?"

### Step 5: Run the Install

Use the `$PLATFORM` value from Step 1 as the `--agent` argument. Install once per target platform (loop if the user requested multiple).

**`gh skill` — one skill:**
```bash
gh skill install {owner}/{repo} {skill-name} --agent {platform} --scope user
```

**`gh skill` — all skills (loop over each name):**
```bash
for SKILL in {skill-name-1} {skill-name-2} ...; do
  gh skill install {owner}/{repo} "$SKILL" --agent {platform} --scope user
done
```

**`npx skills` — specific skill:**
```bash
npx skills add {owner}/{repo} --skill {skill-name} --agent {platform} -g -y
```

**`npx skills` — all skills from repo:**
```bash
npx skills add {owner}/{repo} --agent {platform} -g -y
```

Use `--agent {platform}` and `-g` (global/user scope). Do NOT combine `--agent` with `--all` — the `--all` flag means "install to all agents" and overrides `--agent`, causing installs to unintended locations.

For platform-native installs: run or surface the command from the instruction file. Do not write a registry entry for platform-native installs.

If any install command fails, surface the error output and ask the user how to proceed before continuing.

### Step 6: Update the Registry

`registry.sh write` merges by `repo` key — only the fields you provide are updated; all other existing fields are preserved.

Set shell variables for all substitutions before building the JSON:

```bash
TODAY=$(date +%Y-%m-%d)
SHA=$(gh api "repos/{owner}/{repo}/commits/HEAD" --jq '.sha')
INSTALL_TOOL="gh"          # or "npx" or "manual"
INSTALL_CMD="gh skill install {owner}/{repo} {skill-name} --agent {platform} --scope user"
# For npx-installed skills use: "npx skills add {owner}/{repo} --agent {platform} -g -y"
# JSON array of installed skill names, e.g. '["brainstorming","cli"]'
SKILLS_JSON='["{skill-name-1}","{skill-name-2}"]'

ENTRY=$(python3 -c "
import json, sys
print(json.dumps({
    'repo': sys.argv[1],
    'install_tool': sys.argv[2],
    'install_cmd': sys.argv[3],
    'skills_installed': json.loads(sys.argv[4]),
    'sha': sys.argv[5],
    'installed_at': sys.argv[6]
}))" "{owner}/{repo}" "$INSTALL_TOOL" "$INSTALL_CMD" "$SKILLS_JSON" "$SHA" "$TODAY")

bash "$SKILL_SCRIPTS/registry.sh" write "$ENTRY"
```

---

## Update Flow (`update-skills [repo]`)

### Step 1: Run Update Check

```bash
bash "$SKILL_SCRIPTS/check-updates.sh"
```

The script covers all three paths:
- `gh`-managed: `gh skill update --dry-run` (per-directory tree SHA)
- `npx`/`manual`: HEAD SHA comparison against registry
- Unregistered skill dirs: listed for optional registration

### Step 2: Present and Apply

If nothing to report, tell the user everything is up to date.

Otherwise ask: "Update all, pick specific ones, or skip?"

**`gh`-managed:**
```bash
gh skill update {skill-name} --agent {platform}
```

**`npx`-managed:** Re-run the recorded `install_cmd`. If `install_cmd` is not recorded, ask the user: "I don't have a recorded install command for {skill-name}. Can you provide it, or should I try `npx skills add {repo} --skill {skill-name} --agent {platform} -g -y`?"

**`manual`:** Show the recorded `install_cmd` and the latest release if accessible:
```bash
gh api "repos/{owner}/{repo}/releases/latest" --jq '{tag: .tag_name, notes: .body}' 2>/dev/null || true
```
Work with the user to determine the right update action. If no `install_cmd` is recorded, ask the user for it.

### Step 3: Refresh Registry SHA

After a successful update, refresh the SHA so future checks work correctly:

```bash
SHA=$(gh api "repos/{owner}/{repo}/commits/HEAD" --jq '.sha')
PATCH=$(python3 -c "import json,sys; print(json.dumps({'repo': sys.argv[1], 'sha': sys.argv[2]}))" \
  "{owner}/{repo}" "$SHA")
bash "$SKILL_SCRIPTS/registry.sh" write "$PATCH"
```

### Step 4: Retroactive Registration (if unregistered skills reported)

For each unregistered skill the user wants to register:

1. Ask: "What is the source repo? (e.g., `obra/superpowers`)"
2. Ask: "How was it installed? (`gh`, `npx`, or `manual`)"
3. Ask: "What was the install command? (enter 'unknown' if unsure — future updates will require manual action for this entry)"
4. Fetch SHA and write the entry:

```bash
SHA=$(gh api "repos/{owner}/{repo}/commits/HEAD" --jq '.sha')
TODAY=$(date +%Y-%m-%d)
INSTALL_CMD="unknown"   # or the actual command if known
ENTRY=$(python3 -c "
import json, sys
print(json.dumps({
    'repo': sys.argv[1],
    'install_tool': sys.argv[2],
    'install_cmd': sys.argv[3],
    'skills_installed': [sys.argv[4]],
    'sha': sys.argv[5],
    'installed_at': sys.argv[6]
}))" "{owner}/{repo}" "{tool}" "$INSTALL_CMD" "{skill-name}" "$SHA" "$TODAY")
bash "$SKILL_SCRIPTS/registry.sh" write "$ENTRY"
```
