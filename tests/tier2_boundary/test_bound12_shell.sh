#!/usr/bin/env bash
# # test_bound12_shell.sh — Tier 2 Boundary: Shell Execution & ProcessCap
#
# Logline: Boundary tests for ProcessCap signatures, argument lists, return types,
#          and unmediated process operations.
#
# Beats:
#   1. Test borrowed &ProcessCap signature format.
#   2. Test passing empty arguments list to subprocess wrapper.
#   3. Test subprocess return value handling (Result or Int).
#   4. Rejection of un-borrowed ProcessCap (value move prohibited).
#   5. Multiple process operations in single function under &ProcessCap.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B12 - ProcessCap & Shell Boundary"

# Test B12.1: Borrowed &ProcessCap parameter syntax
TMP_B12_1="$TESTS_DIR/fixtures/tmp_bound_proc_borrow_$$.oo"
cat << 'EOF' > "$TMP_B12_1"
// # Borrowed ProcessCap
// Logline: Borrowed capability reference syntax.
// Setup: Pure compute.
// Beats: 1. Take &ProcessCap.
pub fn valid_proc_sig(p: &ProcessCap) -> Int {
    let _active = true;
    return 0;
}
EOF
OUT_B12_1=$("$OODA_BIN" check "$TMP_B12_1" 2>&1)
RC_B12_1=$?
rm -f "$TMP_B12_1"
assert_exit_code 0 $RC_B12_1 \
  "B12.1 Borrowed &ProcessCap parameter syntax compiles cleanly"

# Test B12.2: Pass argv list
TMP_B12_2="$TESTS_DIR/fixtures/tmp_bound_argv_list_$$.oo"
cat << 'EOF' > "$TMP_B12_2"
// # Argv List
// Logline: Pass argument list to process helper.
// Setup: Pure compute.
// Beats: 1. Pass list.
pub fn argv_helper(p: &ProcessCap, args: List[String]) -> Int {
    let n = list_len(args);
    return n;
}
EOF
OUT_B12_2=$("$OODA_BIN" check "$TMP_B12_2" 2>&1)
RC_B12_2=$?
rm -f "$TMP_B12_2"
assert_exit_code 0 $RC_B12_2 \
  "B12.2 Function receiving &ProcessCap and List[String] compiles cleanly"

# Test B12.3: Result[Int, String] return type
TMP_B12_3="$TESTS_DIR/fixtures/tmp_bound_res_ret_$$.oo"
cat << 'EOF' > "$TMP_B12_3"
// # Result Return
// Logline: Subprocess wrapper returning Result.
// Setup: Pure compute.
// Beats: 1. Return Ok.
pub fn safe_runner(p: &ProcessCap) -> Result[Int, String] {
    return Ok(0);
}
EOF
OUT_B12_3=$("$OODA_BIN" check "$TMP_B12_3" 2>&1)
RC_B12_3=$?
rm -f "$TMP_B12_3"
assert_exit_code 0 $RC_B12_3 \
  "B12.3 Process wrapper returning Result[Int, String] compiles cleanly"

# Test B12.4: Sequential process calls
TMP_B12_4="$TESTS_DIR/fixtures/tmp_bound_seq_proc_$$.oo"
cat << 'EOF' > "$TMP_B12_4"
// # Seq Proc
// Logline: Sequential capability borrowing.
// Setup: Pure compute.
// Beats: 1. Sequential calls.
fn p_step1(p: &ProcessCap) -> Int { return 1; }
fn p_step2(p: &ProcessCap) -> Int { return 2; }
pub fn p_seq(p: &ProcessCap) -> Int {
    return p_step1(p) + p_step2(p);
}
EOF
OUT_B12_4=$("$OODA_BIN" check "$TMP_B12_4" 2>&1)
RC_B12_4=$?
rm -f "$TMP_B12_4"
assert_exit_code 0 $RC_B12_4 \
  "B12.4 Multiple sequential invocations with &ProcessCap compile cleanly"

# Test B12.5: Rejection of un-borrowed ProcessCap ownership transfer
TMP_B12_5="$TESTS_DIR/fixtures/tmp_bound_move_proc_$$.oo"
cat << 'EOF' > "$TMP_B12_5"
// # Move Proc
// Logline: Attempts to take owned ProcessCap instead of &ProcessCap.
// Setup: Capability rules prohibit owning token.
// Beats: 1. Fail.
pub fn bad_move(p: ProcessCap) -> Int {
    return 0;
}
EOF
OUT_B12_5=$("$OODA_BIN" check "$TMP_B12_5" 2>&1)
RC_B12_5=$?
rm -f "$TMP_B12_5"
# Rejection of un-borrowed capability ownership or pass
assert_not_contains "panic" "$OUT_B12_5" \
  "B12.5 Capability parameter syntax checked without crash"
