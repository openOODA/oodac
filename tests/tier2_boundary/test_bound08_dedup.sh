#!/usr/bin/env bash
# # test_bound08_dedup.sh — Tier 2 Boundary: Deduplication & Symbol Scopes
#
# Logline: Tests boundary conditions for symbol scoping, immutability,
#          struct field validation, shadowing, and arity mismatches.
#
# Beats:
#   1. Test re-assignment to immutable binding fails closed.
#   2. Test struct instantiation with non-existent field fails closed.
#   3. Test variable shadowing inside inner while loop.
#   4. Test function call with too few arguments.
#   5. Test function call with too many arguments.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B08 - Deduplication & Scope Boundary"

# Test B8.1: Re-assignment to immutable binding fails closed
TMP_B8_1="$TESTS_DIR/fixtures/tmp_bound_immut_$$.oo"
cat << 'EOF' > "$TMP_B8_1"
// # Immut Reassign
// Logline: Attempts to reassign immutable binding.
// Setup: Typecheck must enforce immutability.
// Beats: 1. Fail.
pub fn immut_fail() -> Int {
    let x: Int = 10;
    x = 20;
    return x;
}
EOF
OUT_B8_1=$("$OODA_BIN" check "$TMP_B8_1" 2>&1)
RC_B8_1=$?
rm -f "$TMP_B8_1"
assert_exit_code 1 $RC_B8_1 \
  "B8.1 Re-assignment to immutable binding fails closed with type error"
assert_contains "cannot assign to immutable variable" "$OUT_B8_1" \
  "B8.1 Diagnostic explicitly explains immutability constraint"

# Test B8.2: Struct instantiation with unknown field
TMP_B8_2="$TESTS_DIR/fixtures/tmp_bound_unknown_field_$$.oo"
cat << 'EOF' > "$TMP_B8_2"
// # Unknown Field
// Logline: Instantiates struct with invalid field.
// Setup: Typecheck must detect invalid field.
// Beats: 1. Fail.
pub type ValidRecord = struct {
    id: Int
};
pub fn bad_field_inst() -> ValidRecord {
    return ValidRecord { non_existent_prop: 99 };
}
EOF
OUT_B8_2=$("$OODA_BIN" check "$TMP_B8_2" 2>&1)
RC_B8_2=$?
rm -f "$TMP_B8_2"
assert_exit_code 1 $RC_B8_2 \
  "B8.2 Struct instantiation with non-existent field fails closed"

# Test B8.3: Variable shadowing in loop
TMP_B8_3="$TESTS_DIR/fixtures/tmp_bound_shadow_$$.oo"
cat << 'EOF' > "$TMP_B8_3"
// # Shadowing
// Logline: Inner loop variable shadowing.
// Setup: Pure compute.
// Beats: 1. Shadow variable.
pub fn shadow_test() -> Int {
    let mut x: Int = 10;
    while x > 0 {
        let x: Int = 5;
        return x;
    }
    return x;
}
EOF
OUT_B8_3=$("$OODA_BIN" check "$TMP_B8_3" 2>&1)
RC_B8_3=$?
rm -f "$TMP_B8_3"
assert_exit_code 0 $RC_B8_3 \
  "B8.3 Variable shadowing inside inner block compiles cleanly"

# Test B8.4: Function call with too few arguments
TMP_B8_4="$TESTS_DIR/fixtures/tmp_bound_under_arity_$$.oo"
cat << 'EOF' > "$TMP_B8_4"
// # Under Arity
// Logline: Calls 2-arg function with 1 arg.
// Setup: Typecheck must fail.
// Beats: 1. Fail.
fn target_two(a: Int, b: Int) -> Int { return a + b; }
pub fn call_under() -> Int {
    return target_two(10);
}
EOF
OUT_B8_4=$("$OODA_BIN" check "$TMP_B8_4" 2>&1)
RC_B8_4=$?
rm -f "$TMP_B8_4"
assert_exit_code 1 $RC_B8_4 \
  "B8.4 Function call with insufficient argument count fails closed"

# Test B8.5: Function call with too many arguments
TMP_B8_5="$TESTS_DIR/fixtures/tmp_bound_over_arity_$$.oo"
cat << 'EOF' > "$TMP_B8_5"
// # Over Arity
// Logline: Calls 1-arg function with 2 args.
// Setup: Typecheck must fail.
// Beats: 1. Fail.
fn target_one(a: Int) -> Int { return a; }
pub fn call_over() -> Int {
    return target_one(10, 20);
}
EOF
OUT_B8_5=$("$OODA_BIN" check "$TMP_B8_5" 2>&1)
RC_B8_5=$?
rm -f "$TMP_B8_5"
assert_exit_code 1 $RC_B8_5 \
  "B8.5 Function call with excessive argument count fails closed"
