#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  SKILLS_DIR=$(mktemp -d)
  export AGENTS_SKILLS_DIR="$SKILLS_DIR"
  MOCKBIN="$TMPDIR/bin"
  mkdir -p "$MOCKBIN"
  SCRIPT="$BATS_TEST_DIRNAME/../skills/skill-manager/scripts/check-updates.sh"
  REGISTRY_SCRIPT="$BATS_TEST_DIRNAME/../skills/skill-manager/scripts/registry.sh"
}

teardown() {
  rm -rf "$TMPDIR" "$SKILLS_DIR"
}

make_mock_gh() {
  local dry_run_output="${1:-}"
  local head_sha="${2:-deadbeef}"
  cat > "$MOCKBIN/gh" << MOCK
#!/usr/bin/env bash
if [[ "\$*" == *"--dry-run"* ]]; then
  echo "$dry_run_output"
elif [[ "\$*" == *"commits/HEAD"* ]] && [[ "\$*" == *"--jq"* ]]; then
  # Simulate gh api ... --jq '.sha' returning just the SHA string
  echo "$head_sha"
elif [[ "\$*" == *"commits/HEAD"* ]]; then
  # No --jq: return raw JSON as real gh would — catches regressions if
  # --jq is accidentally removed from check-updates.sh
  echo '{"sha":"$head_sha","commit":{"message":"test commit"}}'
fi
MOCK
  chmod +x "$MOCKBIN/gh"
}

@test "outputs nothing when registry is empty and no skill dirs" {
  make_mock_gh "" "deadbeef"
  run env PATH="$MOCKBIN:$PATH" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "reports unregistered skill dir" {
  make_mock_gh "" "deadbeef"
  mkdir -p "$SKILLS_DIR/orphan-skill"
  run env PATH="$MOCKBIN:$PATH" bash "$SCRIPT"
  [[ "$output" == *"orphan-skill"* ]]
}

@test "reports SHA change for npx-managed entry" {
  make_mock_gh "" "newsha999"
  bash "$REGISTRY_SCRIPT" write '{"repo":"test/repo","install_tool":"npx","skills_installed":["my-skill"],"sha":"oldsha111"}'
  run env PATH="$MOCKBIN:$PATH" bash "$SCRIPT"
  [[ "$output" == *"SHA changed"* ]]
}

@test "silent when npx SHA is unchanged" {
  make_mock_gh "" "samesha"
  bash "$REGISTRY_SCRIPT" write '{"repo":"test/repo","install_tool":"npx","skills_installed":["my-skill"],"sha":"samesha"}'
  run env PATH="$MOCKBIN:$PATH" bash "$SCRIPT"
  [ "$output" = "" ]
}

@test "surfaces gh skill update --dry-run output for gh-managed entries" {
  make_mock_gh "brainstorming (obra/superpowers) — v5.1.0 → v5.2.0" "deadbeef"
  bash "$REGISTRY_SCRIPT" write '{"repo":"obra/superpowers","install_tool":"gh","skills_installed":["brainstorming"],"sha":"deadbeef"}'
  run env PATH="$MOCKBIN:$PATH" bash "$SCRIPT"
  [[ "$output" == *"brainstorming"* ]]
}
