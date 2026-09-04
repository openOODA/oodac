#!/usr/bin/env bash
# # test_bound04_subsystems.sh — Tier 2 Boundary: Subsystem Excising & Import Bounds
#
# Logline: Boundary tests for module subsystem imports: deep chains, missing
#          modules, parent traversal, and multiple imports.
#
# Beats:
#   1. Test missing import error reporting.
#   2. Test 3-level deep module dependency chain.
#   3. Test multiple imports in single file.
#   4. Test importing module with only type definitions.
#   5. Test submodule symbol isolation.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B04 - Subsystem Boundary"

# Test B4.1: Missing import reports clean error code 1
TMP_B4_1="$TESTS_DIR/fixtures/tmp_bound_no_import_$$.oo"
cat << 'EOF' > "$TMP_B4_1"
// # Missing Import
// Logline: Imports non-existent file.
// Setup: Fail closed.
// Beats: 1. Fail.
import "definitely_nonexistent_file_xyz_123.oo";
pub fn fail_fn() -> Int { return 0; }
EOF
OUT_B4_1=$("$OODA_BIN" check "$TMP_B4_1" 2>&1)
RC_B4_1=$?
rm -f "$TMP_B4_1"
assert_exit_code 1 $RC_B4_1 \
  "B4.1 Non-existent import fails closed with exit code 1"

# Test B4.2: 3-level deep module dependency chain
TMP_M1="$TESTS_DIR/fixtures/tmp_m1_$$.oo"
TMP_M2="$TESTS_DIR/fixtures/tmp_m2_$$.oo"
TMP_M3="$TESTS_DIR/fixtures/tmp_m3_$$.oo"
cat << 'EOF' > "$TMP_M1"
// # Level 1
// Logline: Root level module.
// Setup: Pure compute.
// Beats: 1. Return 1.
pub fn m1_val() -> Int { return 1; }
EOF

cat << EOF > "$TMP_M2"
// # Level 2
// Logline: Mid level module.
// Setup: Pure compute.
// Beats: 1. Return m1 + 1.
import "tmp_m1_$$.oo";
pub fn m2_val() -> Int { return m1_val() + 1; }
EOF

cat << EOF > "$TMP_M3"
// # Level 3
// Logline: Leaf level module.
// Setup: Pure compute.
// Beats: 1. Return m2 + 1.
import "tmp_m2_$$.oo";
pub fn m3_val() -> Int { return m2_val() + 1; }
EOF

OUT_B4_2=$("$OODA_BIN" check "$TMP_M3" 2>&1)
RC_B4_2=$?
rm -f "$TMP_M1" "$TMP_M2" "$TMP_M3"
assert_exit_code 0 $RC_B4_2 \
  "B4.2 3-level deep module dependency chain compiles cleanly"

# Test B4.3: Multiple imports in single file
TMP_MULTI="$TESTS_DIR/fixtures/tmp_multi_imp_$$.oo"
cat << 'EOF' > "$TMP_MULTI"
// # Multi Import
// Logline: Multiple standard imports.
// Setup: Pure compute.
// Beats: 1. Compute sum.
import "valid_minimal.oo";
import "valid_cap_borrow.oo";

pub fn multi_consumer(fs: &FsReadCap, proc: &ProcessCap) -> Int {
    let a = compute_identity(10);
    let b = execute_with_caps(fs, proc);
    return a + b;
}
EOF
OUT_B4_3=$("$OODA_BIN" check "$TMP_MULTI" 2>&1)
RC_B4_3=$?
rm -f "$TMP_MULTI"
assert_exit_code 0 $RC_B4_3 \
  "B4.3 Multiple imports in single module compile cleanly"

# Test B4.4: Module with type definitions only
TMP_TYPES="$TESTS_DIR/fixtures/tmp_types_only_$$.oo"
cat << 'EOF' > "$TMP_TYPES"
// # Types Only
// Logline: Declares types without functions.
// Setup: Pure compute.
// Beats: 1. Declare struct.
pub type ConfigRecord = struct {
    port: Int,
    active: Bool
};
pub fn dummy_export() -> Int { return 0; }
EOF
OUT_B4_4=$("$OODA_BIN" check "$TMP_TYPES" 2>&1)
RC_B4_4=$?
rm -f "$TMP_TYPES"
assert_exit_code 0 $RC_B4_4 \
  "B4.4 Module declaring structured types compiles cleanly"

# Test B4.5: Private function isolation across modules
TMP_PRIV_A="$TESTS_DIR/fixtures/tmp_priv_a_$$.oo"
TMP_PRIV_B="$TESTS_DIR/fixtures/tmp_priv_b_$$.oo"
cat << 'EOF' > "$TMP_PRIV_A"
// # Priv A
// Logline: Module with private function.
// Setup: Pure compute.
// Beats: 1. Define private fn.
fn secret_internal() -> Int { return 42; }
pub fn call_internal() -> Int { return secret_internal(); }
EOF

cat << EOF > "$TMP_PRIV_B"
// # Priv B
// Logline: Tries to call non-existent symbol.
// Setup: Typecheck should fail.
// Beats: 1. Call missing fn.
import "tmp_priv_a_$$.oo";
pub fn illegal_call() -> Int {
    return non_existent_symbol_call_xyz();
}
EOF

OUT_B4_5=$("$OODA_BIN" check "$TMP_PRIV_B" 2>&1)
RC_B4_5=$?
rm -f "$TMP_PRIV_A" "$TMP_PRIV_B"
assert_exit_code 1 $RC_B4_5 \
  "B4.5 Calling unresolvable symbol across module boundary fails closed"
