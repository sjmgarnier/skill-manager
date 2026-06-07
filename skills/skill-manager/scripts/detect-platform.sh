#!/usr/bin/env bash
set -euo pipefail

# Platform detection is best-effort. Results may be inaccurate when multiple
# agent platforms are installed on the same machine. The agent should confirm
# the detected platform with the user before acting on it.
#
# Detection order: env vars (set by the active platform) → running processes
# (active only) → config directories (persistent even when platform is not
# running, so least reliable). Env vars take priority because they are
# injected at session time and are unambiguous.

# 1. Environment variables — injected by the platform at session start
[[ -n "${CLAUDE_CODE:-}" ]]    && echo "claude-code"  && exit 0
[[ -n "${GEMINI_CLI:-}" ]]     && echo "gemini-cli"   && exit 0
[[ -n "${CODEX:-}" ]]          && echo "codex"         && exit 0
[[ -n "${CURSOR_IDE:-}" ]]     && echo "cursor"        && exit 0
[[ -n "${WARP_TERMINAL:-}" ]]  && echo "warp"          && exit 0
[[ -n "${WINDSURF_IDE:-}" ]]   && echo "windsurf"      && exit 0
[[ -n "${GOOSE_SESSION:-}" ]]  && echo "goose"         && exit 0
[[ -n "${CONTINUE_IDE:-}" ]]   && echo "continue"      && exit 0

# 2. Running processes — only active when the platform is actually running,
#    so more reliable than directory checks. Uses character-class trick to
#    avoid matching the grep process itself. Matches the process name field
#    only (ps -eo comm=) to reduce false positives from path/arg substrings.
if command -v ps &>/dev/null; then
  ps -eo comm= 2>/dev/null | grep -qi '^claude'   && echo "claude-code" && exit 0
  ps -eo comm= 2>/dev/null | grep -qi '^gemini'   && echo "gemini-cli"  && exit 0
  ps -eo comm= 2>/dev/null | grep -qi '^codex'    && echo "codex"        && exit 0
  ps -eo comm= 2>/dev/null | grep -qi '^cursor'   && echo "cursor"       && exit 0
  ps -eo comm= 2>/dev/null | grep -qi '^windsurf' && echo "windsurf"     && exit 0
  ps -eo comm= 2>/dev/null | grep -qi '^warp'     && echo "warp"         && exit 0
  ps -eo comm= 2>/dev/null | grep -qi '^goose'    && echo "goose"        && exit 0
fi

# 3. Config directories — created on first install and persist permanently.
#    May produce false positives on machines where a platform was installed
#    but is not currently active (e.g. ~/.claude exists even in Gemini CLI).
[[ -d "${HOME}/.claude" ]]    && echo "claude-code" && exit 0
[[ -d "${HOME}/.gemini" ]]    && echo "gemini-cli"  && exit 0
[[ -d "${HOME}/.cursor" ]]    && echo "cursor"       && exit 0
[[ -d "${HOME}/.warp" ]]      && echo "warp"         && exit 0
[[ -d "${HOME}/.windsurf" ]]  && echo "windsurf"     && exit 0
[[ -d "${HOME}/.continue" ]]  && echo "continue"     && exit 0
[[ -d "${HOME}/.goose" ]]     && echo "goose"        && exit 0

echo "unknown"
