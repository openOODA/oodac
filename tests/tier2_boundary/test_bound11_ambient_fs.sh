#!/usr/bin/env bash
# # test_bound11_ambient_fs.sh — Tier 2 Boundary: Filesystem Capability Bounds
#
# Logline: Boundary tests for &FsReadCap and &FsWriteCap capability mediation:
#          dual capabilities, write_file restrictions, and attenuation.
#
# Beats:
#   1. Test function with both &FsReadCap and &FsWriteCap.
#   2. Test calling write_file without &FsWriteCap token fails closed.
#   3. Test sequential read and write operations under capability tokens.
#   4. Test passing capability token to helper function.
#   5. Verify zero ambient capability leakage in pure function.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B11 - Filesystem Capability Boundary"

# Test B11.1: Dual &FsReadCap and &FsWriteCap
TMP_B11_1="$TESTS_DIR/fixtures/tmp_bound_dual_cap_$$.oo"
cat << 'EOF' > "$TMP_B11_1"
// # Dual Cap
// Logline: Uses both read and write capabilities.
// Setup: Pure compute.
// Beats: 1. Take both caps.
pub fn dual_cap_fn(fs_r: &FsReadCap, fs_w: &FsWriteCap) -> Int {
    let _active = true;
    return 0;
}
EOF
OUT_B11_1=$("$OODA_BIN" check "$TMP_B11_1" 2>&1)
RC_B11_1=$?
rm -f "$TMP_B11_1"
assert_exit_code 0 $RC_B11_1 \
  "B11.1 Function taking both &FsReadCap and &FsWriteCap compiles cleanly"

# Test B11.2: Calling write_file without &FsWriteCap fails closed
TMP_B11_2="$TESTS_DIR/fixtures/tmp_bound_ambient_write_$$.oo"
cat << 'EOF' > "$TMP_B11_2"
// # Ambient Write
// Logline: Calls write_file without cap token.
// Setup: Static cap check must fail.
// Beats: 1. Fail.
pub fn ambient_write_test() {
    write_file("/tmp/hacked.txt", "payload");
}
EOF
OUT_B11_2=$("$OODA_BIN" check "$TMP_B11_2" 2>&1)
RC_B11_2=$?
rm -f "$TMP_B11_2"
assert_exit_code 1 $RC_B11_2 \
  "B11.2 Calling write_file without &FsWriteCap fails compilation"

# Test B11.3: Passing borrowed cap to helper function
TMP_B11_3="$TESTS_DIR/fixtures/tmp_bound_cap_pass_$$.oo"
cat << 'EOF' > "$TMP_B11_3"
// # Pass Cap
// Logline: Passes borrowed cap token to private helper.
// Setup: Pure compute.
// Beats: 1. Pass cap reference.
fn cap_helper(fs: &FsReadCap) -> Int {
    let _active = true;
    return 1;
}
pub fn cap_caller(fs: &FsReadCap) -> Int {
    return cap_helper(fs);
}
EOF
OUT_B11_3=$("$OODA_BIN" check "$TMP_B11_3" 2>&1)
RC_B11_3=$?
rm -f "$TMP_B11_3"
assert_exit_code 0 $RC_B11_3 \
  "B11.3 Passing borrowed capability token to helper function compiles cleanly"

# Test B11.4: Rejection of FsReadCap used for write operation
TMP_B11_4="$TESTS_DIR/fixtures/tmp_bound_wrong_cap_$$.oo"
cat << 'EOF' > "$TMP_B11_4"
// # Wrong Cap
// Logline: Attempts to use &FsReadCap for write_file.
// Setup: Typecheck must fail.
// Beats: 1. Fail.
pub fn wrong_cap_op(fs_r: &FsReadCap) {
    write_file(fs_r, "/tmp/out.txt", "content");
}
EOF
OUT_B11_4=$("$OODA_BIN" check "$TMP_B11_4" 2>&1)
RC_B11_4=$?
rm -f "$TMP_B11_4"
assert_exit_code 1 $RC_B11_4 \
  "B11.4 Using &FsReadCap for write_file is rejected by capability verifier"

# Test B11.5: Pure function with 0 capabilities cannot be passed capability
TMP_B11_5="$TESTS_DIR/fixtures/tmp_bound_pure_no_cap_$$.oo"
cat << 'EOF' > "$TMP_B11_5"
// # Pure No Cap
// Logline: Pure arithmetic function.
// Setup: Pure compute.
// Beats: 1. Add numbers.
pub fn pure_math(a: Int, b: Int) -> Int {
    return a + b;
}
EOF
OUT_B11_5=$("$OODA_BIN" check "$TMP_B11_5" 2>&1)
RC_B11_5=$?
rm -f "$TMP_B11_5"
assert_exit_code 0 $RC_B11_5 \
  "B11.5 Pure compute function requires zero capability tokens"
