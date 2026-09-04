#!/usr/bin/env bash
# # test_bound16_adversarial.sh — Tier 2 Boundary: Adversarial Syntax Probing
#
# Logline: Tests compiler fail-closed resilience against syntax corruptions,
#          unterminated strings, consecutive operators, and missing returns.
#
# Beats:
#   1. Test consecutive operators (1 ++ 2) syntax rejection.
#   2. Test unterminated string literal rejection.
#   3. Test empty parameter list () compilation.
#   4. Test function returning wrong variant of Option.
#   5. Test multiple consecutive empty statements (;;;).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B16 - Adversarial Syntax Boundary"

# Test B16.1: Unclosed brace block fails closed
TMP_B16_1="$TESTS_DIR/fixtures/tmp_bound_unclosed_brace_$$.oo"
cat << 'EOF' > "$TMP_B16_1"
// # Unclosed Brace
// Logline: Missing function closing brace.
// Setup: Parser must detect unclosed block.
// Beats: 1. Fail.
pub fn unclosed_brace() -> Int {
    let x = 42;
    return x;
EOF
OUT_B16_1=$("$OODA_BIN" check "$TMP_B16_1" 2>&1)
RC_B16_1=$?
rm -f "$TMP_B16_1"
assert_exit_code 1 $RC_B16_1 \
  "B16.1 Unclosed brace block fails closed with syntax error"

# Test B16.2: Unterminated string literal
TMP_B16_2="$TESTS_DIR/fixtures/tmp_bound_unterm_str_$$.oo"
cat << 'EOF' > "$TMP_B16_2"
// # Unterm Str
// Logline: Unterminated string.
// Setup: Scanner must fail.
// Beats: 1. Fail.
pub fn bad_str() -> String {
    let s = "unterminated string literal
    return s;
}
EOF
OUT_B16_2=$("$OODA_BIN" check "$TMP_B16_2" 2>&1)
RC_B16_2=$?
rm -f "$TMP_B16_2"
assert_exit_code 1 $RC_B16_2 \
  "B16.2 Unterminated string literal fails closed at scanner"

# Test B16.3: Empty parameter list () compiles cleanly
TMP_B16_3="$TESTS_DIR/fixtures/tmp_bound_empty_params_$$.oo"
cat << 'EOF' > "$TMP_B16_3"
// # Empty Params
// Logline: Function with empty parameter list.
// Setup: Pure compute.
// Beats: 1. Return constant.
pub fn no_params() -> Int {
    return 777;
}
EOF
OUT_B16_3=$("$OODA_BIN" check "$TMP_B16_3" 2>&1)
RC_B16_3=$?
rm -f "$TMP_B16_3"
assert_exit_code 0 $RC_B16_3 \
  "B16.3 Empty parameter list () compiles cleanly"

# Test B16.4: Return type mismatch with Option
TMP_B16_4="$TESTS_DIR/fixtures/tmp_bound_bad_opt_$$.oo"
cat << 'EOF' > "$TMP_B16_4"
// # Bad Opt
// Logline: Returns raw Int instead of Option[Int].
// Setup: Typecheck must fail.
// Beats: 1. Fail.
pub fn returns_wrong_opt() -> Option[Int] {
    return 42;
}
EOF
OUT_B16_4=$("$OODA_BIN" check "$TMP_B16_4" 2>&1)
RC_B16_4=$?
rm -f "$TMP_B16_4"
assert_exit_code 1 $RC_B16_4 \
  "B16.4 Returning raw Int where Option[Int] expected fails closed"

# Test B16.5: Consecutive empty statements
TMP_B16_5="$TESTS_DIR/fixtures/tmp_bound_empty_stmts_$$.oo"
cat << 'EOF' > "$TMP_B16_5"
// # Empty Stmts
// Logline: Multiple semicolons.
// Setup: Pure compute.
// Beats: 1. Return val.
pub fn multi_semi() -> Int {
    let x = 1;
    ;;;
    return x;
}
EOF
OUT_B16_5=$("$OODA_BIN" check "$TMP_B16_5" 2>&1)
RC_B16_5=$?
rm -f "$TMP_B16_5"
# Handled without compiler crash
assert_not_contains "panic" "$OUT_B16_5" \
  "B16.5 Multiple semicolons handled without compiler panic"
