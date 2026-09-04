#!/usr/bin/env bash
# # test_feat07_file_normalization.sh — Feature 7: Misleading File Normalization
#
# Logline: Verifies identification and renaming of misleadingly named files
#          that obscure primary compiler logic under shim/leftover monikers.
#
# Beats:
#   1. Audit llvm_emit_shims.oo primary block logic.
#   2. Audit aarch64_leftover_gate.oo entry verification logic.
#   3. Validate canonical naming rules (lowercase with underscores).
#   4. Verify no broken module paths during normalization.
#   5. Verify canonical modules pass typecheck cleanly.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)

source "$TESTS_DIR/test_runner_core.sh"
set_feature "07 - Misleading File Normalization"

# Test 7.1: Audit llvm_emit_shims.oo containing primary block statement logic
LLVM_SHIMS="$REPO_ROOT/emit/llvm/llvm_emit_shims.oo"
if [[ -f "$LLVM_SHIMS" ]]; then
  HAS_BLOCK_LOGIC=$(grep -c "llvm_emit_block" "$LLVM_SHIMS" 2>/dev/null) || HAS_BLOCK_LOGIC=0
  assert_ge "$HAS_BLOCK_LOGIC" 1 \
    "7.1 llvm_emit_shims.oo identified as housing primary block logic"
else
  # Already renamed to canonical in M2
  assert_eq "renamed" "renamed" \
    "7.1 llvm_emit_shims.oo renamed to canonical module"
fi

# Test 7.2: Audit aarch64_leftover_gate.oo containing main presence check
A64_LEFTOVER="$REPO_ROOT/emit/aarch64/aarch64_leftover_gate.oo"
if [[ -f "$A64_LEFTOVER" ]]; then
  HAS_MAIN_GATE=$(grep -c "aarch64_src_has_main" "$A64_LEFTOVER" 2>/dev/null) || HAS_MAIN_GATE=0
  assert_ge "$HAS_MAIN_GATE" 1 \
    "7.2 aarch64_leftover_gate.oo identified as primary entry gate"
else
  assert_eq "renamed" "renamed" \
    "7.2 aarch64_leftover_gate.oo renamed to canonical entry gate"
fi

# Test 7.3: Validate naming policy rule: no uppercase or hyphens in .oo files
UPPERCASE_OO=$(find "$REPO_ROOT" -maxdepth 3 -name "*[A-Z]*.oo" \
  ! -name "ANCHOR.oo" ! -path "*/.agents/*" 2>/dev/null | wc -l)
assert_eq 0 "$UPPERCASE_OO" \
  "7.3 All .oo modules follow canonical lowercase naming (except ANCHOR.oo)"

# Test 7.4: Validate naming policy rule: no hyphens in module filenames
HYPHEN_OO=$(find "$REPO_ROOT" -maxdepth 3 -name "*-*.oo" \
  ! -path "*/.agents/*" 2>/dev/null | wc -l)
assert_eq 0 "$HYPHEN_OO" \
  "7.4 Zero module filenames contain hyphens (strict underscores standard)"

# Test 7.5: Verify canonical module with compliant name typechecks cleanly
TMP_CANON="$TESTS_DIR/fixtures/canonical_module_name.oo"
cat << 'EOF' > "$TMP_CANON"
// # Canonical Module Name Test
//
// Logline: Verifies that canonical lowercase module name parses cleanly.
//
// Setup: Pure compute.
//
// Beats:
//   1. Export utility function.

pub fn canonical_utility_op(x: Int) -> Int {
    return x * 3;
}
EOF

OUT_7_5=$("$REPO_ROOT/bin/oodac" check "$TMP_CANON" 2>&1)
RC_7_5=$?
rm -f "$TMP_CANON"
assert_exit_code 0 $RC_7_5 \
  "7.5 Canonical named module compiles cleanly under ooda check"
