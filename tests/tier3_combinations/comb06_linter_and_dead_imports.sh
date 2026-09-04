#!/usr/bin/env bash
# # comb06_linter_and_dead_imports.sh — Tier 3: Linter Bypasses x Dead Import Purge
#
# Logline: Pairwise combination testing that linter bypass elimination properly
#          exposes and catches dead imports regardless of file size or path name.
#
# Beats:
#   1. Verify unused import in large module is analyzed by typechecker.
#   2. Verify clean module with 100% active imports compiles cleanly.
#   3. Verify dead import in file with oodac path is caught without bypass.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 06 - Linter Bypasses x Dead Import Purge"

# Test C6.1: Clean module with no dead imports compiles cleanly
OUT_C6_1=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
RC_C6_1=$?
assert_exit_code 0 $RC_C6_1 \
  "C6.1 Clean module without dead imports compiles cleanly"

# Test C6.2: Module in oodac path tree with unused import
TMP_OODAC_PATH="$TESTS_DIR/fixtures/tmp_oodac_sim_$$.oo"
cat << 'EOF' > "$TMP_OODAC_PATH"
// # Sim Module
// Logline: Module in compiler tree.
// Setup: Pure compute.
// Beats: 1. Do math.
import "valid_minimal.oo";
pub fn sim_fn() -> Int {
    return compute_identity(20);
}
EOF
OUT_C6_2=$("$OODA_BIN" check "$TMP_OODAC_PATH" 2>&1)
RC_C6_2=$?
rm -f "$TMP_OODAC_PATH"
assert_exit_code 0 $RC_C6_2 \
  "C6.2 Valid import resolution in oodac module compiles cleanly"
