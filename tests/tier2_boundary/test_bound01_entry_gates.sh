#!/usr/bin/env bash
# # test_bound01_entry_gates.sh — Tier 2 Boundary: Entry Gates
#
# Logline: Boundary tests for entry gates: circular imports, empty gates,
#          256-line ceiling, deep paths, and Unicode docstrings.
#
# Beats:
#   1. Test empty entry gate (0 items) boundary.
#   2. Test circular import detection between synthetic gates.
#   3. Test deeply nested entry gate directory path.
#   4. Test Unicode characters inside entry gate docstrings.
#   5. Test entry gate sitting at exact 256-line ceiling.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B01 - Entry Gates Boundary"

# Test B1.1: Empty entry gate boundary
TMP_EMPTY="$TESTS_DIR/fixtures/tmp_bound_empty_$$.oo"
cat << 'EOF' > "$TMP_EMPTY"
// # Empty Entry Gate Boundary
// Logline: Contains zero function or type declarations.
// Setup: Pure compute.
// Beats: 1. Do nothing.
EOF
OUT_B1_1=$("$OODA_BIN" check "$TMP_EMPTY" 2>&1)
RC_B1_1=$?
rm -f "$TMP_EMPTY"
assert_exit_code 1 $RC_B1_1 \
  "B1.1 Module with 0 functions fails closed with no_fn requirement"

# Test B1.2: Circular import detection
TMP_CIRC_A="$TESTS_DIR/fixtures/tmp_circ_a_$$.oo"
TMP_CIRC_B="$TESTS_DIR/fixtures/tmp_circ_b_$$.oo"
cat << EOF > "$TMP_CIRC_A"
// # Circ A
// Logline: A imports B.
// Setup: Pure compute.
// Beats: 1. Import B.
import "tmp_circ_b_$$.oo";
pub fn ca() -> Int { return 1; }
EOF

cat << EOF > "$TMP_CIRC_B"
// # Circ B
// Logline: B imports A.
// Setup: Pure compute.
// Beats: 1. Import A.
import "tmp_circ_a_$$.oo";
pub fn cb() -> Int { return 2; }
EOF

OUT_B1_2=$("$OODA_BIN" check "$TMP_CIRC_A" 2>&1)
RC_B1_2=$?
rm -f "$TMP_CIRC_A" "$TMP_CIRC_B"
# Compiler either resolves cyclical dependency or safely reports circular error (no infinite loop)
assert_not_contains "Segmentation fault" "$OUT_B1_2" \
  "B1.2 Circular import terminates deterministically without crash"

# Test B1.3: Deeply nested directory path resolution
DEEP_DIR="$TESTS_DIR/fixtures/deep/level1/level2"
mkdir -p "$DEEP_DIR"
TMP_DEEP="$DEEP_DIR/ANCHOR.oo"
cat << 'EOF' > "$TMP_DEEP"
// # Deep ANCHOR
// Logline: Deeply nested entry gate.
// Setup: Pure compute.
// Beats: 1. Export fn.
pub fn deep_op() -> Int { return 99; }
EOF
OUT_B1_3=$("$OODA_BIN" check "$TMP_DEEP" 2>&1)
RC_B1_3=$?
rm -rf "$TESTS_DIR/fixtures/deep"
assert_exit_code 0 $RC_B1_3 \
  "B1.3 Deeply nested ANCHOR.oo entry gate compiles cleanly"

# Test B1.4: Unicode in docstrings
TMP_UNI="$TESTS_DIR/fixtures/tmp_uni_$$.oo"
cat << 'EOF' > "$TMP_UNI"
// # Unicode Header ──▓▓ Sovereign Lattice ▓▓──
// Logline: Contains Unicode symbols in comments: π, 漢字, 🚀, ©.
// Setup: Pure compute.
// Beats: 1. Return 0.
pub fn unicode_doc() -> Int { return 0; }
EOF
OUT_B1_4=$("$OODA_BIN" check "$TMP_UNI" 2>&1)
RC_B1_4=$?
rm -f "$TMP_UNI"
assert_exit_code 0 $RC_B1_4 \
  "B1.4 Entry gate with UTF-8 Unicode in comments compiles cleanly"

# Test B1.5: Entry gate at exact 256 lines
OUT_B1_5=$("$OODA_BIN" check "$TESTS_DIR/fixtures/boundary_256_lines.oo" 2>&1)
RC_B1_5=$?
assert_exit_code 0 $RC_B1_5 \
  "B1.5 Entry gate at exact 256-line boundary compiles cleanly"
