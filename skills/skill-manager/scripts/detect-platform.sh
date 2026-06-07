#!/usr/bin/env bash
set -euo pipefail

# 1. Environment variables (most reliable — set by the platform itself)
[[ -n "${CLAUDE_CODE:-}" ]] && echo "claude-code" && exit 0
[[ -n "${GEMINI_CLI:-}" ]] && echo "gemini-cli" && exit 0
[[ -n "${CODEX:-}" ]] && echo "codex" && exit 0
[[ -n "${CURSOR_IDE:-}" ]] && echo "cursor" && exit 0
[[ -n "${WARP_TERMINAL:-}" ]] && echo "warp" && exit 0

# 2. Config directories (created by the platform on first run)
[[ -d "${HOME}/.claude" ]] && echo "claude-code" && exit 0
[[ -d "${HOME}/.gemini" ]] && echo "gemini-cli" && exit 0
[[ -d "${HOME}/.cursor" ]] && echo "cursor" && exit 0
[[ -d "${HOME}/.warp" ]] && echo "warp" && exit 0

# 3. Process names (least reliable — only works if platform is running)
if command -v ps &>/dev/null; then
  ps aux 2>/dev/null | grep -qi '[c]laude' && echo "claude-code" && exit 0
  ps aux 2>/dev/null | grep -qi '[g]emini' && echo "gemini-cli" && exit 0
  ps aux 2>/dev/null | grep -qi '[c]ursor' && echo "cursor" && exit 0
  ps aux 2>/dev/null | grep -qi '[w]arp' && echo "warp" && exit 0
fi

echo "unknown"
