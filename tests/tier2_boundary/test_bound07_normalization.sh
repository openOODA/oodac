#!/usr/bin/env bash
# # test_bound07_normalization.sh — Tier 2 Boundary: Identifiers & Normalization
#
# Logline: Boundary tests for identifier lengths, reserved keyword collisions,
#          single-letter names, and underscore combinations.
#
# Beats:
#   1. Test single-letter identifier boundary.
#   2. Test 100-character long identifier.
#   3. Test trailing underscore identifiers.
#   4. Test reserved keyword identifier collision rejection.
#   5. Test multiple consecutive underscores in names.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B07 - Identifiers & Normalization Boundary"

# Test B7.1: Single-letter identifier
TMP_B7_1="$TESTS_DIR/fixtures/tmp_bound_single_char_$$.oo"
cat << 'EOF' > "$TMP_B7_1"
// # Single Char Ident
// Logline: Valid single character identifiers.
// Setup: Pure compute.
// Beats: 1. Return x.
pub fn a(x: Int) -> Int {
    let y: Int = x;
    return y;
}
EOF
OUT_B7_1=$("$OODA_BIN" check "$TMP_B7_1" 2>&1)
RC_B7_1=$?
rm -f "$TMP_B7_1"
assert_exit_code 0 $RC_B7_1 \
  "B7.1 Single-letter variable and function identifiers compile cleanly"

# Test B7.2: Long identifier (80 characters)
LONG_NAME="a_very_long_variable_identifier_name_used_for_boundary_testing_of_the_scanner_01"
TMP_B7_2="$TESTS_DIR/fixtures/tmp_bound_long_ident_$$.oo"
cat << EOF > "$TMP_B7_2"
// # Long Ident
// Logline: 80 character identifier.
// Setup: Pure compute.
// Beats: 1. Return long ident.
pub fn long_ident_test() -> Int {
    let $LONG_NAME: Int = 42;
    return $LONG_NAME;
}
EOF
OUT_B7_2=$("$OODA_BIN" check "$TMP_B7_2" 2>&1)
RC_B7_2=$?
rm -f "$TMP_B7_2"
assert_exit_code 0 $RC_B7_2 \
  "B7.2 80-character long identifier compiles cleanly"

# Test B7.3: Trailing underscore identifier
TMP_B7_3="$TESTS_DIR/fixtures/tmp_bound_trail_under_$$.oo"
cat << 'EOF' > "$TMP_B7_3"
// # Trailing Underscore
// Logline: Identifiers with trailing underscores.
// Setup: Pure compute.
// Beats: 1. Return v_.
pub fn trail_under(v_: Int) -> Int {
    let res_ = v_ + 1;
    return res_;
}
EOF
OUT_B7_3=$("$OODA_BIN" check "$TMP_B7_3" 2>&1)
RC_B7_3=$?
rm -f "$TMP_B7_3"
assert_exit_code 0 $RC_B7_3 \
  "B7.3 Trailing underscore identifiers compile cleanly"

# Test B7.4: Illegal symbol character in identifier
TMP_B7_4="$TESTS_DIR/fixtures/tmp_bound_illegal_char_$$.oo"
cat << 'EOF' > "$TMP_B7_4"
// # Illegal Char Ident
// Logline: Attempts to use illegal character @ in variable identifier.
// Setup: Parsing must fail closed.
// Beats: 1. Fail.
pub fn bad_ident() -> Int {
    let @var = 10;
    return 0;
}
EOF
OUT_B7_4=$("$OODA_BIN" check "$TMP_B7_4" 2>&1)
RC_B7_4=$?
rm -f "$TMP_B7_4"
assert_exit_code 1 $RC_B7_4 \
  "B7.4 Illegal symbol character in variable identifier fails compilation"

# Test B7.5: Multiple consecutive underscores
TMP_B7_5="$TESTS_DIR/fixtures/tmp_bound_multi_under_$$.oo"
cat << 'EOF' > "$TMP_B7_5"
// # Multi Under
// Logline: Consecutive underscores in identifier.
// Setup: Pure compute.
// Beats: 1. Return val.
pub fn multi_under_test() -> Int {
    let custom__internal___name = 99;
    return custom__internal___name;
}
EOF
OUT_B7_5=$("$OODA_BIN" check "$TMP_B7_5" 2>&1)
RC_B7_5=$?
rm -f "$TMP_B7_5"
assert_exit_code 0 $RC_B7_5 \
  "B7.5 Consecutive underscores in variable identifier compile cleanly"
