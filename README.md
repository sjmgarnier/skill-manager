# skill-manager

A [`SKILL.md`](https://agentskills.io/specification) agent skill for installing and updating agent skills from GitHub repos into `~/.agents/skills/`.

## Install

```bash
gh skill install sjmgarnier/skill-manager skill-manager --agent codex --scope user
```

Replace `codex` with your target agent, such as `claude-code`, `goose`,
`gemini-cli`, `cursor`, `warp`, `windsurf`, or `continue`.

## Requirements

- `gh` (GitHub CLI >= v2.90.0)
- `git`
- `python3` (stdlib only — no extra packages needed)
- `npx` (optional, for `npx skills`-based repos)

## Usage

Once installed, trigger via your agent:

- `install-skills <owner>/<repo>` — e.g., `install-skills obra/superpowers`
- `update-skills` — check and apply updates for all tracked skills
- `update-skills <owner>/<repo>` — check and apply updates for one repo

## Development

```bash
brew install bats-core
bats tests/
```
