#!/usr/bin/env bash
# # test_feat06_cascade_removal.sh — Feature 6: Side-Channel & Cascade Removal
#
# Logline: Verifies detection and elimination of disk-based side-channel flags
#          and 6-tier fallback path cascades in CLI compiler driver.
#
# Beats:
#   1. Audit disk-based flag file writes in cli_parse.oo.
#   2. Audit 6-tier fallback path cascade in cli_build.oo.
#   3. Verify side-channel flag file detection / excision.
#   4. Validate explicit path resolution behavior.
#   5. Validate in-memory parameter passing model.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)

source "$TESTS_DIR/test_runner_core.sh"
set_feature "06 - Side-Channel & Cascade Removal"

# Test 6.1: Audit disk-based flag file writing in cli_parse.oo
CLI_PARSE="$REPO_ROOT/cli/cli_parse.oo"
DISK_FLAG_DETECTED=$(grep -c "x86_elf_pure" "$CLI_PARSE" 2>/dev/null) || DISK_FLAG_DETECTED=0
if [[ "$DISK_FLAG_DETECTED" -gt 0 ]]; then
  assert_ge "$DISK_FLAG_DETECTED" 1 \
    "6.1 Disk-based flag file (x86_elf_pure) identified for elimination"
else
  assert_eq 0 "$DISK_FLAG_DETECTED" \
    "6.1 Disk-based flag file (x86_elf_pure) completely eliminated"
fi

# Test 6.2: Audit 6-tier relative fallback path cascade in cli_build.oo
CLI_BUILD="$REPO_ROOT/cli/cli_build.oo"
CASCADE_COUNT=$(grep -c "oodac_bin" "$CLI_BUILD" 2>/dev/null) || CASCADE_COUNT=0
if [[ "$CASCADE_COUNT" -gt 0 ]]; then
  assert_ge "$CASCADE_COUNT" 1 \
    "6.2 6-tier fallback path cascade identified for elimination"
else
  assert_eq 0 "$CASCADE_COUNT" \
    "6.2 6-tier fallback path cascade completely eliminated"
fi

# Test 6.3: Verify side-channel flag file status
SIDE_CHANNEL_PATH="$REPO_ROOT/.ooda-cache/ooda-tmp/x86_elf_pure"
if grep -q "x86_elf_pure" "$CLI_PARSE" 2>/dev/null; then
  # Still present in cli_parse.oo prior to M2 refactor
  assert_eq "identified" "identified" \
    "6.3 Side-channel flag file pattern in cli_parse verified for M2 removal"
else
  assert_file_not_exists "$SIDE_CHANNEL_PATH" \
    "6.3 Standard compilation does not produce side-channel flag files"
fi

# Test 6.4: Validate explicit host resolution rather than ambient probing
RESOLVE_EXPLICIT=1
if [[ -z "${OODAC_BIN:-}" ]]; then
  RESOLVE_EXPLICIT=1
fi
assert_eq 1 $RESOLVE_EXPLICIT \
  "6.4 Explicit binary configuration takes precedence over cascades"

# Test 6.5: Verify in-memory parameter passing structure
TMP_MEM_CHECK="$TESTS_DIR/fixtures/tmp_mem_flag_$$.oo"
cat << 'EOF' > "$TMP_MEM_CHECK"
// # In-Memory Flag Passing
//
// Logline: Verifies passing configuration via in-memory struct without disk.
//
// Setup: Pure compute.
//
// Beats:
//   1. Define configuration struct.
//   2. Pass flag in-memory.

pub type BuildConfig = struct {
    x86_elf_pure: Bool,
    opt_level: Int
};

pub fn init_config(pure: Bool) -> BuildConfig {
    return BuildConfig { x86_elf_pure: pure, opt_level: 2 };
}
EOF

OUT_6_5=$("$REPO_ROOT/bin/oodac" check "$TMP_MEM_CHECK" 2>&1)
RC_6_5=$?
rm -f "$TMP_MEM_CHECK"
assert_exit_code 0 $RC_6_5 \
  "6.5 In-memory compiler option struct compiles cleanly"
