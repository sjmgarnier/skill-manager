#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../skills/skill-manager/scripts/detect-platform.sh"

@test "detects claude-code from CLAUDE_CODE env var" {
  run env CLAUDE_CODE=1 bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "claude-code" ]
}

@test "detects gemini-cli from GEMINI_CLI env var" {
  run env GEMINI_CLI=1 bash "$SCRIPT"
  [ "$output" = "gemini-cli" ]
}

@test "detects claude-code from ~/.claude config dir" {
  TMPHOME=$(mktemp -d)
  MOCKBIN=$(mktemp -d)
  mkdir -p "$TMPHOME/.claude"
  # Stub ps to return nothing so only the directory tier is tested
  printf '#!/bin/bash\necho ""\n' > "$MOCKBIN/ps"
  chmod +x "$MOCKBIN/ps"
  run env HOME="$TMPHOME" PATH="$MOCKBIN:$PATH" bash "$SCRIPT"
  rm -rf "$TMPHOME" "$MOCKBIN"
  [ "$output" = "claude-code" ]
}

@test "detects gemini-cli from ~/.gemini config dir" {
  TMPHOME=$(mktemp -d)
  MOCKBIN=$(mktemp -d)
  mkdir -p "$TMPHOME/.gemini"
  # Stub ps to return nothing so only the directory tier is tested
  printf '#!/bin/bash\necho ""\n' > "$MOCKBIN/ps"
  chmod +x "$MOCKBIN/ps"
  run env HOME="$TMPHOME" PATH="$MOCKBIN:$PATH" bash "$SCRIPT"
  rm -rf "$TMPHOME" "$MOCKBIN"
  [ "$output" = "gemini-cli" ]
}

@test "returns unknown when no signals found" {
  TMPHOME=$(mktemp -d)
  MOCKBIN=$(mktemp -d)
  # Stub ps to return nothing so live processes don't interfere
  printf '#!/bin/bash\necho ""\n' > "$MOCKBIN/ps"
  chmod +x "$MOCKBIN/ps"
  run env -i PATH="$MOCKBIN:$PATH" HOME="$TMPHOME" bash "$SCRIPT"
  rm -rf "$TMPHOME" "$MOCKBIN"
  [ "$output" = "unknown" ]
}

@test "process check takes priority over config dir (detects active platform)" {
  # ~/.gemini exists (old install) but a claude-code process is running
  TMPHOME=$(mktemp -d)
  MOCKBIN=$(mktemp -d)
  mkdir -p "$TMPHOME/.gemini"
  # Stub ps to report a claude process
  printf '#!/bin/bash\necho "claude"\n' > "$MOCKBIN/ps"
  chmod +x "$MOCKBIN/ps"
  run env -i PATH="$MOCKBIN:$PATH" HOME="$TMPHOME" bash "$SCRIPT"
  rm -rf "$TMPHOME" "$MOCKBIN"
  [ "$output" = "claude-code" ]
}
