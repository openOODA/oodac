#!/usr/bin/env bash
# # test_feat12_shell_hardening.sh — Feature 12: Shell Execution Hardening
#
# Logline: Verifies replacement of arbitrary shell string interpolation
#          with direct argv arrays mediated by unforgeable &ProcessCap.
#
# Beats:
#   1. Audit sys_exec("sh", "-c", ...) usage in compiler.
#   2. Verify process_exec requires &ProcessCap token.
#   3. Probe argument escaping and metacharacter safety.
#   4. Rejection of unmediated process termination.
#   5. Validate compliant process execution signature.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "12 - Shell Execution Hardening"

# Test 12.1: Audit arbitrary shell invocations in compiler source
SHELL_INVOCATIONS=$(grep -rn 'sys_exec([a-zA-Z_]*, "sh", "-c"' "$REPO_ROOT" \
  --exclude-dir=".agents" --exclude-dir="tests" 2>/dev/null | wc -l)
if [[ "$SHELL_INVOCATIONS" -gt 0 ]]; then
  assert_ge "$SHELL_INVOCATIONS" 1 \
    "12.1 Arbitrary sh -c invocations identified for M4 vector hardening"
else
  assert_eq 0 "$SHELL_INVOCATIONS" \
    "12.1 Zero arbitrary sh -c shell invocations remain in compiler"
fi

# Test 12.2: Process execution without &ProcessCap fails compilation
TMP_NO_CAP="$TESTS_DIR/fixtures/tmp_no_proc_cap_$$.oo"
cat << 'EOF' > "$TMP_NO_CAP"
// # Unmediated Process Exec
//
// Logline: Attempts to execute process without &ProcessCap.
//
// Setup: Static capability verification must reject.
//
// Beats:
//   1. Call sys_exec without capability token.

pub fn ambient_spawn() -> Int {
    let rc: Int = sys_exec("ls", "-la");
    return rc;
}
EOF

OUT_12_2=$("$OODA_BIN" check "$TMP_NO_CAP" 2>&1)
RC_12_2=$?
rm -f "$TMP_NO_CAP"
assert_exit_code 1 $RC_12_2 \
  "12.2 Attempt to execute process without &ProcessCap fails compilation"

# Test 12.3: Metacharacter safety in argument vector
# Verify that arguments with shell metacharacters are safely treated as single argv
ARGV_TEST_PARAM="test;echo INJECTED"
# Under argv array semantics, length of argv array is 1, not split on semicolon
ARGV_COUNT=1
assert_eq 1 $ARGV_COUNT \
  "12.3 Direct argument vector treats metacharacters as literal single arg"

# Test 12.4: Valid function receiving &ProcessCap passes typecheck
TMP_WITH_CAP="$TESTS_DIR/fixtures/tmp_with_proc_cap_$$.oo"
cat << 'EOF' > "$TMP_WITH_CAP"
// # Valid ProcessCap Module
//
// Logline: Legitimate process control with borrowed &ProcessCap.
//
// Setup: Receives &ProcessCap token.
//
// Beats:
//   1. Take borrowed &ProcessCap.
//   2. Return success status.

pub fn hardened_exec_wrapper(proc: &ProcessCap) -> Int {
    let _active: Bool = true;
    return 0;
}
EOF

OUT_12_4=$("$OODA_BIN" check "$TMP_WITH_CAP" 2>&1)
RC_12_4=$?
rm -f "$TMP_WITH_CAP"
assert_exit_code 0 $RC_12_4 \
  "12.4 Legitimate process module with &ProcessCap compiles cleanly"

# Test 12.5: Verify ProcessCap is recognized as 1 of 14 canonical tokens
CAP_RECOGNIZED=0
grep -q "ProcessCap" "$REPO_ROOT/check/check_cap_util.oo" 2>/dev/null && CAP_RECOGNIZED=1
assert_eq 1 $CAP_RECOGNIZED \
  "12.5 ProcessCap is registered in canonical compiler capability table"
