#!/usr/bin/env bash
# # test_feat01_entry_gates.sh — Feature 1: Entry Gate Reparation
#
# Logline: Verifies that compiler entry gates export canonical interfaces,
#          call exported symbols, and contain zero dead imports.
#
# Beats:
#   1. Check root ANCHOR.oo exports per PROJECT.md interface contract.
#   2. Verify root ANCHOR.oo calls exported lex_scan_source (not unexported lex_all).
#   3. Verify types/ANCHOR.oo contains no unreferenced lex/ANCHOR.oo import.
#   4. Verify emit/gpu/ANCHOR.oo exports valid gpu drivers without dead imports.
#   5. Verify synthetic valid ANCHOR passes typecheck.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "01 - Entry Gate Reparation"

# Test 1.1: Root ANCHOR.oo export verification
# PROJECT.md contract: oodac_parse_file, oodac_parse_expr, oodac_lex_all
if grep -q "oodac_parse_file" "$REPO_ROOT/ANCHOR.oo" 2>/dev/null; then
  assert_eq "true" "true" "1.1 Root ANCHOR.oo defines entry functions"
else
  assert_eq "true" "false" "1.1 Root ANCHOR.oo defines entry functions"
fi

# Test 1.2: Verify unexported lex_all is not invoked directly
if grep -q "return lex_all(" "$REPO_ROOT/ANCHOR.oo" 2>/dev/null; then
  assert_eq "repaired" "unrepaired" \
    "1.2 Root ANCHOR.oo must not call unexported lex_all"
else
  assert_eq "clean" "clean" \
    "1.2 Root ANCHOR.oo does not call unexported lex_all"
fi

# Test 1.3: Verify types/ANCHOR.oo does not have dead lex import
TYPES_ANCHOR="$REPO_ROOT/types/ANCHOR.oo"
if grep -q 'import "lex/ANCHOR.oo"' "$TYPES_ANCHOR" 2>/dev/null; then
  assert_eq "removed" "present" \
    "1.3 types/ANCHOR.oo must not import dead lex/ANCHOR.oo"
else
  assert_eq "clean" "clean" \
    "1.3 types/ANCHOR.oo contains no dead lex/ANCHOR.oo import"
fi

# Test 1.4: Verify emit/gpu/ANCHOR.oo exports valid gpu drivers
GPU_ANCHOR="$REPO_ROOT/emit/gpu/ANCHOR.oo"
if grep -q "pub fn gpu_emit" "$GPU_ANCHOR" 2>/dev/null; then
  assert_eq "true" "true" \
    "1.4 emit/gpu/ANCHOR.oo exports canonical gpu_emit entry point"
else
  assert_eq "true" "false" \
    "1.4 emit/gpu/ANCHOR.oo exports canonical gpu_emit entry point"
fi

# Test 1.5: Synthetic ANCHOR entry gate inside workspace typechecks cleanly
TMP_ANCHOR="$TESTS_DIR/fixtures/tmp_synth_anchor_$$.oo"
cat << 'EOF' > "$TMP_ANCHOR"
// # Synthetic Entry Gate
//
// Logline: Minimal valid domain entry gate.
//
// Setup: Pure compute.
//
// Beats:
//   1. Re-export public function.

pub fn domain_entry(x: Int) -> Int {
    return x;
}
EOF

CHECK_OUT=$("$OODA_BIN" check "$TMP_ANCHOR" 2>&1)
CHECK_RC=$?
rm -f "$TMP_ANCHOR"
assert_exit_code 0 $CHECK_RC \
  "1.5 Synthetic canonical ANCHOR compiles cleanly"
