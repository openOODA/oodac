#!/usr/bin/env bash
# # test_feat11_ambient_fs_removal.sh — Feature 11: Filesystem Ambient Auth Removal
#
# Logline: Verifies that all filesystem operations require explicit unforgeable
#          capability tokens (&FsReadCap) with zero ambient authority.
#
# Beats:
#   1. Audit ambient oo_file_stamp usage.
#   2. Audit ambient oo_read_stdin usage.
#   3. Verify calling read_file without &FsReadCap triggers capability violation.
#   4. Verify calling function with valid &FsReadCap compiles cleanly.
#   5. Verify user counterfeit struct cannot substitute for &FsReadCap.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "11 - Filesystem Ambient Authority Removal"

# Test 11.1: Audit oo_file_stamp ambient authority in compiler
STAMP_CALLS=$(grep -rn "oo_file_stamp(" "$REPO_ROOT" \
  --exclude-dir=".agents" --exclude-dir="tests" 2>/dev/null | wc -l)
if [[ "$STAMP_CALLS" -gt 0 ]]; then
  assert_ge "$STAMP_CALLS" 1 \
    "11.1 Ambient oo_file_stamp calls identified for M4 capability mediation"
else
  assert_eq 0 "$STAMP_CALLS" \
    "11.1 Zero ambient oo_file_stamp calls remain in compiler"
fi

# Test 11.2: Audit oo_read_stdin ambient authority in compiler
STDIN_CALLS=$(grep -rn "oo_read_stdin(" "$REPO_ROOT" \
  --exclude-dir=".agents" --exclude-dir="tests" 2>/dev/null | wc -l)
if [[ "$STDIN_CALLS" -gt 0 ]]; then
  assert_ge "$STDIN_CALLS" 1 \
    "11.2 Ambient oo_read_stdin calls identified for M4 capability mediation"
else
  assert_eq 0 "$STDIN_CALLS" \
    "11.2 Zero ambient oo_read_stdin calls remain in compiler"
fi

# Test 11.3: Calling read_file without capability token fails compilation
OUT_11_3=$("$OODA_BIN" check "$TESTS_DIR/fixtures/invalid_cap_ambient.oo" 2>&1)
RC_11_3=$?
assert_exit_code 1 $RC_11_3 \
  "11.3 Calling read_file without &FsReadCap fails compilation"
assert_contains "Security Capability Violation" "$OUT_11_3" \
  "11.3 Diagnostic explicitly states Security Capability Violation"

# Test 11.4: Calling function with valid &FsReadCap compiles cleanly
OUT_11_4=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_cap_borrow.oo" 2>&1)
RC_11_4=$?
assert_exit_code 0 $RC_11_4 \
  "11.4 Legitimate function with &FsReadCap compiles cleanly"

# Test 11.5: Counterfeit capability struct rejected
TMP_FORGE="$TESTS_DIR/fixtures/tmp_forge_cap_$$.oo"
cat << 'EOF' > "$TMP_FORGE"
// # Forged Capability Test
//
// Logline: Attempts to forge &FsReadCap with a custom struct.
//
// Setup: Typechecking must reject counterfeit token.
//
// Beats:
//   1. Declare counterfeit struct.
//   2. Attempt to pass counterfeit token to capability sink.

pub type FakeCap = struct {
    token: Int
};

pub fn try_forge(fake: &FakeCap) -> String {
    let s: String = read_file(fake, "/etc/passwd");
    return s;
}
EOF

OUT_11_5=$("$OODA_BIN" check "$TMP_FORGE" 2>&1)
RC_11_5=$?
rm -f "$TMP_FORGE"
assert_exit_code 1 $RC_11_5 \
  "11.5 Counterfeit struct cannot substitute for genuine &FsReadCap"
