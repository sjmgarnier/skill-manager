#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../skills/skill-manager/scripts/detect-platform.sh"

# Helper: copy the script into a fake platform install path and run it from there
run_from_path() {
  local platform_dir="$1"
  local tmphome
  tmphome=$(mktemp -d)
  local script_dir="$tmphome/$platform_dir/skill-manager/scripts"
  mkdir -p "$script_dir"
  cp "$SCRIPT" "$script_dir/detect-platform.sh"
  run env HOME="$tmphome" bash "$script_dir/detect-platform.sh"
  rm -rf "$tmphome"
}

# --- Primary: install-path detection ---

@test "detects claude-code from install path" {
  run_from_path ".claude/skills"
  [ "$output" = "claude-code" ]
}

@test "detects goose from install path" {
  run_from_path ".config/goose/skills"
  [ "$output" = "goose" ]
}

@test "detects gemini-cli from install path" {
  run_from_path ".gemini/skills"
  [ "$output" = "gemini-cli" ]
}

@test "detects cursor from install path" {
  run_from_path ".cursor/skills"
  [ "$output" = "cursor" ]
}

@test "detects windsurf from install path" {
  run_from_path ".codeium/windsurf/skills"
  [ "$output" = "windsurf" ]
}

@test "detects warp from install path" {
  run_from_path ".agents/skills"
  [ "$output" = "warp" ]
}

# --- Fallback: env var detection (for development / unlisted platforms) ---

@test "falls back to CLAUDE_CODE env var when path is unknown" {
  TMPHOME=$(mktemp -d)
  run env HOME="$TMPHOME" CLAUDE_CODE=1 bash "$SCRIPT"
  rm -rf "$TMPHOME"
  [ "$output" = "claude-code" ]
}

@test "falls back to GEMINI_CLI env var when path is unknown" {
  TMPHOME=$(mktemp -d)
  run env HOME="$TMPHOME" GEMINI_CLI=1 bash "$SCRIPT"
  rm -rf "$TMPHOME"
  [ "$output" = "gemini-cli" ]
}

@test "returns unknown when no path match and no env vars" {
  TMPHOME=$(mktemp -d)
  run env -i HOME="$TMPHOME" PATH="$PATH" bash "$SCRIPT"
  rm -rf "$TMPHOME"
  [ "$output" = "unknown" ]
}
