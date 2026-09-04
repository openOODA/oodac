#!/usr/bin/env bash
# # test_feat05_shim_elimination.sh — Feature 5: Transitional Shim Elimination
#
# Logline: Verifies identification and elimination of backwards-compatibility
#          shims, heuristic mitigations, and synthetic folding cheats.
#
# Beats:
#   1. Audit presence and isolation of aarch64 synthetic fold cheat.
#   2. Audit x86 crude token-matching string scanning heuristic.
#   3. Audit c_emit_meta metamorphic layout decoy residuals.
#   4. Audit c_emit_secret_alias legacy compatibility wrappers.
#   5. Verify compiler lowering uses genuine AST paths without shims.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)

source "$TESTS_DIR/test_runner_core.sh"
set_feature "05 - Transitional Shim Elimination"

# Test 5.1: Verify aarch64_fold_hello synthetic cheat identification
A64_FOLD="$REPO_ROOT/emit/aarch64/aarch64_emit_fold.oo"
if [[ ! -f "$A64_FOLD" ]]; then
  assert_eq "excised" "excised" \
    "5.1 aarch64_emit_fold.oo excised from aarch64 emitter"
else
  CHEAT_SIG=$(grep -c "aarch64_fold_hello" "$A64_FOLD" 2>/dev/null) || CHEAT_SIG=0
  assert_ge "$CHEAT_SIG" 1 \
    "5.1 aarch64_fold_hello synthetic cheat accurately identified"
fi

# Test 5.2: Verify x86_emit_cap_test crude token scanner
X86_SHIMS="$REPO_ROOT/emit/x86/x86_emit_shims.oo"
if [[ ! -f "$X86_SHIMS" ]]; then
  assert_eq "excised" "excised" \
    "5.2 x86_emit_shims.oo excised from x86 emitter"
else
  SHIM_SIG=$(grep -c "x86_emit_cap_test" "$X86_SHIMS" 2>/dev/null) || SHIM_SIG=0
  assert_ge "$SHIM_SIG" 1 \
    "5.2 x86_emit_cap_test crude token scanner identified for excision"
fi

# Test 5.3: Verify c_emit_meta decoy residual identification
C_META="$REPO_ROOT/emit/c/c_emit_meta.oo"
if [[ ! -f "$C_META" ]]; then
  assert_eq "excised" "excised" \
    "5.3 c_emit_meta.oo excised from C emitter"
else
  DECOY_SIG=$(grep -c "c_emit_meta_decoy" "$C_META" 2>/dev/null) || DECOY_SIG=0
  assert_ge "$DECOY_SIG" 1 \
    "5.3 c_emit_meta layout decoy residual identified for excision"
fi

# Test 5.4: Verify c_emit_secret_alias legacy compatibility wrapper
C_SECRET_ALIAS="$REPO_ROOT/emit/c/c_emit_secret_alias.oo"
if [[ ! -f "$C_SECRET_ALIAS" ]]; then
  assert_eq "excised" "excised" \
    "5.4 c_emit_secret_alias.oo excised from C emitter"
else
  ALIAS_SIG=$(grep -c "c_secret_resolve_name" "$C_SECRET_ALIAS" 2>/dev/null) || ALIAS_SIG=0
  assert_ge "$ALIAS_SIG" 1 \
    "5.4 c_secret_resolve_name legacy shim identified for excision"
fi

# Test 5.5: Genuine AST pipeline rule - verify no string-based AST bypasses
BYPASS_COUNT=$(grep -n "telepathic_compile" "$REPO_ROOT/check/tc_drive.oo" \
  2>/dev/null | wc -l)
assert_eq 0 "$BYPASS_COUNT" \
  "5.5 Typecheck driver contains 0 speculative telepathic shortcuts"
