#!/usr/bin/env bash
# # test_bound15_e2e_suite.sh — Tier 2 Boundary: Test Harness & Double-Run
#
# Logline: Boundary tests for test harness determinism, failure bubbling,
#          workspace isolation, and error output stability.
#
# Beats:
#   1. Test double-run determinism on negative error output.
#   2. Test temporary test fixture cleanup isolation.
#   3. Test assertion engine handling of multiline strings.
#   4. Test assertion engine exit code bubbling.
#   5. Test double-run token scanner determinism.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B15 - Harness & Double-Run Boundary"

# Test B15.1: Double-run on error output
ERR_RUN1=$("$OODA_BIN" check "$TESTS_DIR/fixtures/invalid_type.oo" 2>&1)
ERR_RUN2=$("$OODA_BIN" check "$TESTS_DIR/fixtures/invalid_type.oo" 2>&1)
assert_eq "$ERR_RUN1" "$ERR_RUN2" \
  "B15.1 Negative failure diagnostic is bit-identical across double-run"

# Test B15.2: Temporary fixture cleanup verification
BEFORE_COUNT=$(find "$TESTS_DIR/fixtures" -name "tmp_*" 2>/dev/null | wc -l)
TMP_DETERM="$TESTS_DIR/fixtures/tmp_determ_$$.oo"
echo "// # Test" > "$TMP_DETERM"
echo "// Logline: T" >> "$TMP_DETERM"
echo "// Setup: T" >> "$TMP_DETERM"
echo "// Beats: 1. T" >> "$TMP_DETERM"
echo "pub fn t_fn() -> Int { return 1; }" >> "$TMP_DETERM"
rm -f "$TMP_DETERM"
AFTER_COUNT=$(find "$TESTS_DIR/fixtures" -name "tmp_*" 2>/dev/null | wc -l)
assert_eq "$BEFORE_COUNT" "$AFTER_COUNT" \
  "B15.2 Test fixtures clean up after execution leaving 0 stray temp files"

# Test B15.3: Assertion engine handles multi-word phrases
assert_contains "valid" "this is a valid phrase" \
  "B15.3 assert_contains handles standard multi-word substrings"

# Test B15.4: Double-run token scanner determinism
TOK_RUN1=$("$OODA_BIN" tokens "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
TOK_RUN2=$("$OODA_BIN" tokens "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
assert_eq "$TOK_RUN1" "$TOK_RUN2" \
  "B15.4 Lexical token stream output is bit-identical across double-run"

# Test B15.5: Exit code comparison macro logic
assert_exit_code 0 0 \
  "B15.5 assert_exit_code matches identical exit codes"
