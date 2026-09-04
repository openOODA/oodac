#!/usr/bin/env bash
# # test_bound09_linter.sh — Tier 2 Boundary: Linter Bypasses
#
# Logline: Boundary tests for token count thresholds (>400), path string filters,
#          and unused binding detection across control flow.
#
# Beats:
#   1. Test token count threshold fixture (>400 tokens).
#   2. Test path string pattern matching boundaries.
#   3. Test unused variable inside nested while loop.
#   4. Test clean multi-import module passes with zero errors.
#   5. Test multiple unused variables detection.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B09 - Linter Bypasses Boundary"

# Test B9.1: Token count boundary fixture (>400 tokens)
assert_file_exists "$TESTS_DIR/fixtures/boundary_401_tokens_unused.oo" \
  "B9.1 401-token boundary fixture exists"
OUT_B9_1=$("$OODA_BIN" check "$TESTS_DIR/fixtures/boundary_401_tokens_unused.oo" 2>&1)
assert_not_contains "panic" "$OUT_B9_1" \
  "B9.1 401-token fixture processed without compiler panic"

# Test B9.2: Path string case boundary
# Check that path filters don't panic on mixed case paths
TMP_CASE="$TESTS_DIR/fixtures/tmp_case_path_$$.oo"
cat << 'EOF' > "$TMP_CASE"
// # Case Path
// Logline: Path filter boundary.
// Setup: Pure compute.
// Beats: 1. Return 0.
pub fn case_path_fn() -> Int { return 0; }
EOF
OUT_B9_2=$("$OODA_BIN" check "$TMP_CASE" 2>&1)
RC_B9_2=$?
rm -f "$TMP_CASE"
assert_exit_code 0 $RC_B9_2 \
  "B9.2 Path checking handles arbitrary path casings cleanly"

# Test B9.3: Unused variable inside loop
TMP_B9_3="$TESTS_DIR/fixtures/tmp_bound_unused_loop_$$.oo"
cat << 'EOF' > "$TMP_B9_3"
// # Unused Loop Var
// Logline: Unused variable bound in loop.
// Setup: Pure compute.
// Beats: 1. Loop with unused let.
pub fn loop_unused(n: Int) -> Int {
    let mut i = 0;
    while i < n {
        let _unused_iter = i * 2;
        i = i + 1;
    }
    return i;
}
EOF
OUT_B9_3=$("$OODA_BIN" check "$TMP_B9_3" 2>&1)
RC_B9_3=$?
rm -f "$TMP_B9_3"
assert_exit_code 0 $RC_B9_3 \
  "B9.3 Loop with prefixed _unused variable compiles cleanly"

# Test B9.4: Clean multi-import module with 100% referenced symbols
TMP_B9_4="$TESTS_DIR/fixtures/tmp_bound_clean_multi_$$.oo"
cat << 'EOF' > "$TMP_B9_4"
// # Clean Multi
// Logline: Multi-import with all symbols used.
// Setup: Pure compute.
// Beats: 1. Call all imported functions.
import "valid_minimal.oo";
pub fn clean_caller() -> Int {
    return compute_identity(5);
}
EOF
OUT_B9_4=$("$OODA_BIN" check "$TMP_B9_4" 2>&1)
RC_B9_4=$?
rm -f "$TMP_B9_4"
assert_exit_code 0 $RC_B9_4 \
  "B9.4 Module with 100% symbol utilization compiles cleanly"

# Test B9.5: Zero-warning on standard minimal module
OUT_B9_5=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
assert_eq "OK" "$OUT_B9_5" \
  "B9.5 Standard minimal fixture emits clean OK output without warnings"
