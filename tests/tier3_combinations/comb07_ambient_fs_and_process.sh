#!/usr/bin/env bash
# # comb07_ambient_fs_and_process.sh — Tier 3: Filesystem x Process Capabilities
#
# Logline: Pairwise combination testing dual capability requirements for
#          systems executing both filesystem I/O and subprocess execution.
#
# Beats:
#   1. Verify module requiring both &FsReadCap and &ProcessCap compiles cleanly.
#   2. Verify missing &FsReadCap fails while &ProcessCap is present.
#   3. Verify missing &ProcessCap fails while &FsReadCap is present.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 07 - Filesystem x Process Capabilities"

# Test C7.1: Module with both valid capabilities compiles cleanly
TMP_DUAL="$TESTS_DIR/fixtures/tmp_dual_sys_$$.oo"
cat << 'EOF' > "$TMP_DUAL"
// # Dual System
// Logline: Both FsReadCap and ProcessCap present.
// Setup: Pure compute.
// Beats: 1. Hold capabilities.
pub fn run_sys_pipeline(fs: &FsReadCap, p: &ProcessCap) -> Int {
    let _active = true;
    return 0;
}
EOF
OUT_C7_1=$("$OODA_BIN" check "$TMP_DUAL" 2>&1)
RC_C7_1=$?
rm -f "$TMP_DUAL"
assert_exit_code 0 $RC_C7_1 \
  "C7.1 Module taking both &FsReadCap and &ProcessCap compiles cleanly"

# Test C7.2: Calling read_file when only &ProcessCap is held fails closed
TMP_MISS_FS="$TESTS_DIR/fixtures/tmp_miss_fs_$$.oo"
cat << 'EOF' > "$TMP_MISS_FS"
// # Miss FS
// Logline: Holds ProcessCap but tries to read_file.
// Setup: Capability check must fail.
// Beats: 1. Fail.
pub fn bad_fs_call(p: &ProcessCap) -> String {
    return read_file("/etc/hosts");
}
EOF
OUT_C7_2=$("$OODA_BIN" check "$TMP_MISS_FS" 2>&1)
RC_C7_2=$?
rm -f "$TMP_MISS_FS"
assert_exit_code 1 $RC_C7_2 \
  "C7.2 Calling read_file with only &ProcessCap fails closed with cap violation"
