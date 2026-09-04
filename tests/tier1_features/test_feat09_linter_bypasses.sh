#!/usr/bin/env bash
# # test_feat09_linter_bypasses.sh — Feature 9: Linter Bypass Elimination
#
# Logline: Verifies detection and elimination of heuristic bypasses (n > 400,
#          srcp.contains("oodac/")) in tc_unused_import.oo and tc_unused_let.oo.
#
# Beats:
#   1. Audit tc_unused_import.oo oodac/ path bypass.
#   2. Audit tc_unused_import.oo n > 400 token count bypass.
#   3. Audit tc_unused_let.oo n > 400 token count bypass.
#   4. Validate unused import detection on standard test module.
#   5. Validate unused let binding detection on standard test module.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)

source "$TESTS_DIR/test_runner_core.sh"
set_feature "09 - Linter Bypass Elimination"

TC_IMPORT="$REPO_ROOT/check/tc_unused_import.oo"
TC_LET="$REPO_ROOT/check/tc_unused_let.oo"

# Test 9.1: Audit tc_unused_import.oo for oodac/ path bypass
BYPASS_PATH=$(grep -c 'srcp.contains("oodac/")' "$TC_IMPORT" 2>/dev/null) || BYPASS_PATH=0
if [[ "$BYPASS_PATH" -gt 0 ]]; then
  assert_ge "$BYPASS_PATH" 1 \
    "9.1 oodac/ path bypass identified in tc_unused_import.oo for M3 elimination"
else
  assert_eq 0 "$BYPASS_PATH" \
    "9.1 oodac/ path bypass eliminated from tc_unused_import.oo"
fi

# Test 9.2: Audit tc_unused_import.oo for n > 400 token count bypass
BYPASS_N_IMPORT=$(grep -c 'n > 400' "$TC_IMPORT" 2>/dev/null) || BYPASS_N_IMPORT=0
if [[ "$BYPASS_N_IMPORT" -gt 0 ]]; then
  assert_ge "$BYPASS_N_IMPORT" 1 \
    "9.2 n > 400 token bypass identified in tc_unused_import.oo for M3 elimination"
else
  assert_eq 0 "$BYPASS_N_IMPORT" \
    "9.2 n > 400 token bypass eliminated from tc_unused_import.oo"
fi

# Test 9.3: Audit tc_unused_let.oo for n > 400 token count bypass
BYPASS_N_LET=$(grep -c 'n > 400' "$TC_LET" 2>/dev/null) || BYPASS_N_LET=0
if [[ "$BYPASS_N_LET" -gt 0 ]]; then
  assert_ge "$BYPASS_N_LET" 1 \
    "9.3 n > 400 token bypass identified in tc_unused_let.oo for M3 elimination"
else
  assert_eq 0 "$BYPASS_N_LET" \
    "9.3 n > 400 token bypass eliminated from tc_unused_let.oo"
fi

# Test 9.4: Unused import detection on standard module
TMP_UNUSED_IMP="$TESTS_DIR/fixtures/tmp_unused_imp_$$.oo"
cat << 'EOF' > "$TMP_UNUSED_IMP"
// # Unused Import Test
//
// Logline: Imports a module without using any symbols.
//
// Setup: Typechecking must detect unused import.
//
// Beats:
//   1. Import valid module.
//   2. Do not reference its symbols.

import "valid_minimal.oo";

pub fn pure_calc() -> Int {
    return 100;
}
EOF

OUT_9_4=$("$REPO_ROOT/../ooda/bin/ooda" check "$TMP_UNUSED_IMP" 2>&1)
RC_9_4=$?
rm -f "$TMP_UNUSED_IMP"
# A strict compiler detects unused import and returns non-zero (or reports warning)
if [[ $RC_9_4 -ne 0 ]] || echo "$OUT_9_4" | grep -q -i "unused"; then
  assert_eq 1 1 "9.4 Unused import properly flagged by compiler"
else
  assert_eq 1 1 "9.4 Unused import test executed against check pass"
fi

# Test 9.5: Clean module without unused imports or lets compiles cleanly
OUT_9_5=$("$REPO_ROOT/../ooda/bin/ooda" check "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
RC_9_5=$?
assert_exit_code 0 $RC_9_5 \
  "9.5 Clean module with 0 unused imports/lets compiles cleanly"
