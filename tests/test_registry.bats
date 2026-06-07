#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  export AGENTS_SKILLS_DIR="$TMPDIR"
  SCRIPT="$BATS_TEST_DIRNAME/../skills/skill-manager/scripts/registry.sh"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "read returns empty array when no registry exists" {
  run bash "$SCRIPT" read
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "write creates registry and returns success" {
  run bash "$SCRIPT" write '{"repo":"test/repo","install_tool":"gh","skills_installed":["foo"],"sha":"abc123","installed_at":"2026-06-07"}'
  [ "$status" -eq 0 ]
}

@test "write then read returns the entry" {
  bash "$SCRIPT" write '{"repo":"test/repo","install_tool":"gh","skills_installed":["foo"],"sha":"abc123","installed_at":"2026-06-07"}'
  run bash "$SCRIPT" read
  [ "$status" -eq 0 ]
  [[ "$output" == *'"test/repo"'* ]]
  [[ "$output" == *'"abc123"'* ]]
}

@test "write updates existing entry by repo" {
  bash "$SCRIPT" write '{"repo":"test/repo","install_tool":"gh","sha":"old123"}'
  bash "$SCRIPT" write '{"repo":"test/repo","sha":"new456"}'
  run bash "$SCRIPT" read
  [[ "$output" == *'"new456"'* ]]
  [[ "$output" != *'"old123"'* ]]
}

@test "write preserves other entries" {
  bash "$SCRIPT" write '{"repo":"alpha/repo","sha":"aaa"}'
  bash "$SCRIPT" write '{"repo":"beta/repo","sha":"bbb"}'
  run bash "$SCRIPT" read
  [[ "$output" == *'"alpha/repo"'* ]]
  [[ "$output" == *'"beta/repo"'* ]]
}

@test "list-unregistered returns dirs with no registry entry and no gh frontmatter" {
  mkdir -p "$TMPDIR/my-skill"
  run bash "$SCRIPT" list-unregistered
  [ "$status" -eq 0 ]
  [[ "$output" == *"my-skill"* ]]
}

@test "list-unregistered ignores dirs with gh frontmatter" {
  mkdir -p "$TMPDIR/gh-skill"
  printf -- "---\nname: gh-skill\nmetadata:\n  github-repo: https://github.com/foo/bar\n---\n" \
    > "$TMPDIR/gh-skill/SKILL.md"
  run bash "$SCRIPT" list-unregistered
  [[ "$output" != *"gh-skill"* ]]
}

@test "list-unregistered ignores registered skills" {
  mkdir -p "$TMPDIR/my-skill"
  bash "$SCRIPT" write '{"repo":"test/repo","skills_installed":["my-skill"],"sha":"abc"}'
  run bash "$SCRIPT" list-unregistered
  [[ "$output" != *"my-skill"* ]]
}

@test "list-unregistered ignores dot-prefixed entries" {
  mkdir -p "$TMPDIR/.registry-dir"
  run bash "$SCRIPT" list-unregistered
  [[ "$output" != *".registry-dir"* ]]
}
