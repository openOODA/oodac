#!/usr/bin/env bash
# # test_bound03_typecheck.sh — Tier 2 Boundary: Typecheck Assurance
#
# Logline: Tests typechecker boundary values: extreme integers, empty strings,
#          deep nesting, and void returns.
#
# Beats:
#   1. Test zero-statement function returning Void.
#   2. Test 64-bit integer upper bound literal.
#   3. Test 64-bit integer lower bound literal.
#   4. Test deeply nested arithmetic expressions.
#   5. Test empty string literal evaluation.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B03 - Typecheck Boundary"

# Test B3.1: Void return function
TMP_B3_1="$TESTS_DIR/fixtures/tmp_bound_void_$$.oo"
cat << 'EOF' > "$TMP_B3_1"
// # Void Function
// Logline: Minimal void function.
// Setup: Pure compute.
// Beats: 1. Return nothing.
pub fn nop_fn() {
}
EOF
OUT_B3_1=$("$OODA_BIN" check "$TMP_B3_1" 2>&1)
RC_B3_1=$?
rm -f "$TMP_B3_1"
assert_exit_code 0 $RC_B3_1 \
  "B3.1 Void function compiles cleanly"

# Test B3.2: 64-bit max integer
TMP_B3_2="$TESTS_DIR/fixtures/tmp_bound_maxint_$$.oo"
cat << 'EOF' > "$TMP_B3_2"
// # Max Int
// Logline: 64-bit max integer literal.
// Setup: Pure compute.
// Beats: 1. Return max int.
pub fn max_int_fn() -> Int {
    let m: Int = 9223372036854775807;
    return m;
}
EOF
OUT_B3_2=$("$OODA_BIN" check "$TMP_B3_2" 2>&1)
RC_B3_2=$?
rm -f "$TMP_B3_2"
assert_exit_code 0 $RC_B3_2 \
  "B3.2 64-bit max integer literal compiles cleanly"

# Test B3.3: 64-bit min integer
TMP_B3_3="$TESTS_DIR/fixtures/tmp_bound_minint_$$.oo"
cat << 'EOF' > "$TMP_B3_3"
// # Min Int
// Logline: 64-bit min integer literal.
// Setup: Pure compute.
// Beats: 1. Return min int.
pub fn min_int_fn() -> Int {
    let m: Int = -9223372036854775807;
    return m;
}
EOF
OUT_B3_3=$("$OODA_BIN" check "$TMP_B3_3" 2>&1)
RC_B3_3=$?
rm -f "$TMP_B3_3"
assert_exit_code 0 $RC_B3_3 \
  "B3.3 64-bit min integer literal compiles cleanly"

# Test B3.4: Deeply nested expressions
TMP_B3_4="$TESTS_DIR/fixtures/tmp_bound_nest_expr_$$.oo"
cat << 'EOF' > "$TMP_B3_4"
// # Nested Expr
// Logline: Deeply nested arithmetic.
// Setup: Pure compute.
// Beats: 1. Return nested expr.
pub fn nest_expr_fn() -> Int {
    let res = ((((((((1 + 2) + 3) + 4) + 5) + 6) + 7) + 8) + 9);
    return res;
}
EOF
OUT_B3_4=$("$OODA_BIN" check "$TMP_B3_4" 2>&1)
RC_B3_4=$?
rm -f "$TMP_B3_4"
assert_exit_code 0 $RC_B3_4 \
  "B3.4 Deeply nested arithmetic expression compiles cleanly"

# Test B3.5: Empty string literal
TMP_B3_5="$TESTS_DIR/fixtures/tmp_bound_emptystr_$$.oo"
cat << 'EOF' > "$TMP_B3_5"
// # Empty String
// Logline: Empty string literal evaluation.
// Setup: Pure compute.
// Beats: 1. Return empty string.
pub fn empty_str_fn() -> String {
    return "";
}
EOF
OUT_B3_5=$("$OODA_BIN" check "$TMP_B3_5" 2>&1)
RC_B3_5=$?
rm -f "$TMP_B3_5"
assert_exit_code 0 $RC_B3_5 \
  "B3.5 Empty string literal compiles cleanly"
