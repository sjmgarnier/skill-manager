#!/usr/bin/env bash
set -euo pipefail

# Primary detection: derive platform from the script's own install path.
# gh skill install places skills in platform-specific directories, so the
# install location is the most reliable platform signal available.
SCRIPT_DIR="$(python3 -c "import os,sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))" "$0")"
HOME_DIR="$(python3 -c "import os; print(os.path.realpath(os.path.expanduser('~')))")"

case "$SCRIPT_DIR" in
  "$HOME_DIR/.claude/"*)            echo "claude-code" && exit 0 ;;
  "$HOME_DIR/.config/goose/"*)      echo "goose"       && exit 0 ;;
  "$HOME_DIR/.gemini/"*)            echo "gemini-cli"  && exit 0 ;;
  "$HOME_DIR/.cursor/"*)            echo "cursor"       && exit 0 ;;
  "$HOME_DIR/.codeium/windsurf/"*)  echo "windsurf"     && exit 0 ;;
  "$HOME_DIR/.continue/"*)          echo "continue"     && exit 0 ;;
  "$HOME_DIR/.codex/"*)             echo "codex"        && exit 0 ;;
  "$HOME_DIR/.agents/"*)            echo "warp"         && exit 0 ;;
esac

# Fallback: env vars (covers development/testing and unlisted platforms)
[[ -n "${CLAUDE_CODE:-}" ]]   && echo "claude-code" && exit 0
[[ -n "${GEMINI_CLI:-}" ]]    && echo "gemini-cli"  && exit 0
[[ -n "${CODEX:-}" ]]         && echo "codex"        && exit 0
[[ -n "${CURSOR_IDE:-}" ]]    && echo "cursor"       && exit 0
[[ -n "${WARP_TERMINAL:-}" ]] && echo "warp"         && exit 0
[[ -n "${WINDSURF_IDE:-}" ]]  && echo "windsurf"     && exit 0
[[ -n "${GOOSE_SESSION:-}" ]] && echo "goose"        && exit 0
[[ -n "${CONTINUE_IDE:-}" ]]  && echo "continue"     && exit 0

echo "unknown"
