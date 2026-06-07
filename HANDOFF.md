# Skill Manager — Handoff Document

This document captures the full design context from a brainstorming session so the next agent can complete the design and implement the skill in a fresh session.

---

## What We Are Building

A **`SKILL.md` agent skill** called `skill-manager` (or `install-update-skills`) that lives in `~/.agents/skills/skill-manager/`. It guides an AI agent through:

1. **Installing** a skill set from any GitHub repo
2. **Updating** previously installed skill sets by comparing HEAD SHA against the recorded install SHA

This is a single skill for non-Claude-Code agents (the generic `~/.agents/skills/` directory). It is **not** a shell script — it is agent instructions that the AI follows interactively.

---

## Problem Context

### The Skills Directory

`~/.agents/skills/` is the shared skill directory for non-agent-specific agents (Gemini CLI, Codex, OpenCode, Cursor, Warp, and many others). Skills are subdirectories containing at minimum a `SKILL.md` file.

Currently, skills in `~/.agents/skills/` were installed manually with no record of their source repo, version, or install mechanism. There is no way to check for or apply updates.

### Two Real-World Repos with Very Different Structures

**`posit-dev/skills`** (`https://github.com/posit-dev/skills`):
- Skills are grouped in category subdirectories at the repo root: `github/pr-create/SKILL.md`, `r-lib/cli/SKILL.md`, `quarto/quarto-authoring/SKILL.md`, etc.
- Two root-level skills not in a category: `alt-text/SKILL.md`, `brand-yml/SKILL.md`
- Has a `.claude-plugin/marketplace.json` listing all skills and their paths
- Install mechanism: `npx skills add posit-dev/skills --skill <name>` (from `vercel-labs/skills`)
- `gh skill install posit-dev/skills` only finds the 2 root-level skills — the nested category skills are invisible to it (confirmed by testing)
- `gh skill install posit-dev/skills posit-dev/critical-code-reviewer` also fails — `gh skill` does not support slash-delimited paths

**`obra/superpowers`** (`https://github.com/obra/superpowers`):
- Follows the agentskills.io standard: `skills/*/SKILL.md`
- Has `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `AGENTS.md`, `GEMINI.md`, `CLAUDE.md` — install instructions per agent platform
- Has `package.json` with npm versioning and tagged releases
- Install mechanism: `gh skill install obra/superpowers <skill-name>` works perfectly; also `/plugin install` for Claude Code; also platform-specific instructions in AGENTS.md/GEMINI.md/CLAUDE.md for other agents

### The Two Existing Tools

| Tool | Handles | Update command |
|---|---|---|
| `gh skill` (GitHub CLI ≥ v2.90.0) | agentskills.io `skills/*/SKILL.md` layout | `gh skill update --dry-run` / `--all` |
| `npx skills` (vercel-labs/skills) | agentskills.io + `marketplace.json` repos | `npx skills update` |

`gh skill install` injects provenance metadata into `SKILL.md` frontmatter on install:
```yaml
metadata:
  github-repo: https://github.com/obra/superpowers
  github-ref: refs/tags/v5.1.0
  github-tree-sha: f260c775073816860fef8a37c032ac77e2ff5821
  github-path: skills/brainstorming
```

`gh skill update` reads this frontmatter and compares tree SHA against remote to detect changes. `gh skill update --dry-run` reports available updates without applying them.

For skills without frontmatter metadata, `gh skill update` prompts interactively for the source repo, then writes metadata so future updates work.

---

## Proposed Architecture

### Core Idea

A `SKILL.md` that instructs an agent to act as a skill package manager. The agent does the repo inspection and decision-making; it delegates the mechanical install/update work to `gh skill` or `npx skills` as appropriate.

### The Skill Has Two Modes

**Install mode** (`install-skills <repo>`):

1. Fetch the repo's file tree (via `gh api repos/{owner}/{repo}/git/trees/main?recursive=1`)
2. Inspect for install signals (in priority order):
   - Platform-specific instruction files: `AGENTS.md`, `GEMINI.md`, `CLAUDE.md`, `.opencode/INSTALL.md` — read these and follow the instructions for the current platform if present
   - `skills/*/SKILL.md` pattern → use `gh skill install owner/repo`
   - `.claude-plugin/marketplace.json` or similar → use `npx skills add owner/repo`
   - README.md install section → surface it to the user and ask how to proceed
   - None of the above → work with the user to find a solution (manual clone, etc.)
3. Run the chosen install command
4. Record the install in `~/.agents/skills/.registry.yaml`:
   ```yaml
   - repo: posit-dev/skills
     skills:
       - name: pr-create
         path: github/pr-create
     install_tool: npx
     install_cmd: "npx skills add posit-dev/skills --skill pr-create -a universal -y"
     sha: 6a0af655...
     installed_at: 2026-06-07
   ```
   For `gh skill`-installed skills, the frontmatter already stores provenance, so the registry entry is minimal (just `repo`, `sha`, `install_tool: gh`).

**Update mode** (`update-skills [repo]`):

1. Read `~/.agents/skills/.registry.yaml`
2. For each entry (or the specified repo):
   - Fetch current HEAD SHA: `gh api repos/{owner}/{repo}/commits/main --jq '.sha'`
   - Compare against recorded SHA
   - If changed: report which skills have updates available and their changelogs if accessible
3. For `gh`-tracked skills: additionally run `gh skill update --dry-run` (it has finer-grained tree-SHA comparison per skill directory, not just repo HEAD)
4. Present a summary: "3 skills have updates: brainstorming (obra/superpowers v5.1.0 → v5.2.0), pr-create (posit-dev/skills, SHA changed), cli (posit-dev/skills, SHA changed)"
5. Ask the user which to update, then run the appropriate install command with `--force`

### Registry File

`~/.agents/skills/.registry.yaml` — written by the skill, read by the skill. Human-editable. Example:

```yaml
# Managed by skill-manager. Do not edit manually unless you know what you are doing.
entries:
  - repo: obra/superpowers
    install_tool: gh
    install_cmd: "gh skill install obra/superpowers --scope user"
    skills_installed:
      - brainstorming
      - systematic-debugging
      - test-driven-development
    sha: f2cbfbef...
    installed_at: 2026-06-07

  - repo: posit-dev/skills
    install_tool: npx
    install_cmd: "npx skills add posit-dev/skills --all -a universal -y"
    skills_installed:
      - pr-create
      - cli
      - r-package-development
      - quarto-authoring
    sha: 6a0af655...
    installed_at: 2026-06-07
```

---

## Key Design Decisions

1. **No auto-update / cron.** Dropped as too complex for now. The skill is always invoked manually by the user or agent.

2. **SHA tracking at repo HEAD level** for the registry (simple), plus `gh skill`'s finer-grained tree-SHA for `gh`-managed skills (already handled natively by `gh skill update --dry-run`).

3. **Registry lives in `~/.agents/skills/.registry.yaml`** (hidden file, not a skill directory). The dot prefix prevents it from being treated as a skill by agent hosts.

4. **The skill delegates to existing tools** (`gh skill`, `npx skills`) — it does not reimplement install/download logic.

5. **Falls back gracefully**: if neither tool applies, the skill reads the README and surfaces install instructions to the user, then records whatever manual command was agreed upon.

6. **`gh skill` is preferred** when applicable — it has supply chain integrity features (tree SHA per directory, immutable releases, version pinning) that `npx skills` lacks.

---

## What Needs to Be Done

1. **Complete the design spec** — flesh out the `SKILL.md` instructions (the actual agent-facing content), including exact decision logic, prompts, and registry format
2. **Implement `SKILL.md`** — write the skill file
3. **Test** against both `posit-dev/skills` and `obra/superpowers` in a real agent session
4. **Consider**: should existing skills in `~/.agents/skills/` without registry entries be retroactively registered? (e.g., run update-mode and prompt for source repos of unknown skills — `gh skill update` already does this for gh-tracked skills)

---

## Relevant Files and Commands

```bash
# Current skills directory
~/.agents/skills/

# Test installs done during brainstorming (can be cleaned up)
/tmp/skill-test/       # alt-text from posit-dev/skills via gh skill
/tmp/skill-test2/      # pr-create via --from-local (local-path tracking, not usable)
/tmp/skill-test3/      # failed posit-dev category test
/tmp/skill-test4/      # failed slash-path test
/tmp/posit-dev-skills/ # shallow clone of posit-dev/skills

# Key commands tested and confirmed working
gh skill install posit-dev/skills alt-text --dir /tmp/skill-test
gh skill install obra/superpowers brainstorming --dir /tmp/skill-test
gh skill update --dry-run
npx skills add posit-dev/skills --skill pr-create -a universal -y
gh api repos/posit-dev/skills/git/trees/main?recursive=1
```

---

## Useful References

- agentskills.io specification: https://agentskills.io/specification
- gh skill CLI docs: https://cli.github.com/manual/gh_skill
- gh skill install docs: https://cli.github.com/manual/gh_skill_install
- gh skill update docs: https://cli.github.com/manual/gh_skill_update
- vercel-labs/skills (npx skills): https://github.com/vercel-labs/skills
- posit-dev/skills repo: https://github.com/posit-dev/skills
- obra/superpowers repo: https://github.com/obra/superpowers
