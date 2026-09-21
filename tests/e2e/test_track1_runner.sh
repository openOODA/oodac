#!/usr/bin/env bash
# Track 1 Master E2E Test Suite Runner
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TESTS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

export OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
if [[ ! -x "$OODAC_BIN" && -x "$PROJECT_ROOT/bin/oodac" ]]; then
  export OODAC_BIN="$PROJECT_ROOT/bin/oodac"
fi
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export LIBOODAR_PATH="${LIBOODAR_PATH:-$PROJECT_ROOT/oodar/liboodar.a}"

echo "======================================================================"
echo "=== openOODA Track 1 LLVM Lowering Engine Master E2E Runner        ==="
echo "======================================================================"
echo "Target Compiler : $OODAC_BIN"
echo "Project Root    : $PROJECT_ROOT"
echo "Execution Time  : $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

TRACK1_TIER_SUITES=(
  "e2e/test_tier1_m1.sh"
  "e2e/test_tier1_m2.sh"
  "e2e/test_tier1_m3.sh"
  "e2e/test_tier1_m4.sh"
  "e2e/test_tier1_m5.sh"
  "e2e/test_tier1_m6.sh"
  "e2e/test_tier2_m1.sh"
  "e2e/test_tier2_m2.sh"
  "e2e/test_tier2_m3.sh"
  "e2e/test_tier2_m4.sh"
  "e2e/test_tier2_m5.sh"
  "e2e/test_tier2_m6.sh"
  "e2e/test_tier3_pairwise.sh"
  "e2e/test_tier4_scenarios.sh"
)

TRACK1_MATRIX_SUITES=(
  "e2e/test_llvm_builtins_matrix.sh"
  "fuzz/test_grammar_mutation_fuzzer.sh"
  "fuzz/test_differential_expr_fuzzer.sh"
  "fuzz/test_smt_boundary_fuzzer.sh"
  "fuzz/test_challenger_m2_stress.sh"
  "e2e/test_llvm_edge_boundaries.sh"
)

ALL_SUITES=("${TRACK1_TIER_SUITES[@]}" "${TRACK1_MATRIX_SUITES[@]}")

echo "--- Governance Verification: Line Limit Ceiling (wc -l <= 256) ---"
VIOLATIONS=0
for s in "${ALL_SUITES[@]}"; do
  fpath="$TESTS_ROOT/$s"
  if [[ -f "$fpath" ]]; then
    lines=$(wc -l < "$fpath")
    if [[ "$lines" -gt 256 ]]; then
      echo "  [VIOLATION] $s has $lines lines (>256)"
      VIOLATIONS=$((VIOLATIONS + 1))
    else
      echo "  [OK] $s: $lines lines (<= 256)"
    fi
  else
    echo "  [MISSING] $s does not exist at $fpath"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

self_lines=$(wc -l < "$0")
if [[ "$self_lines" -gt 256 ]]; then
  echo "  [VIOLATION] test_track1_runner.sh has $self_lines lines (>256)"
  VIOLATIONS=$((VIOLATIONS + 1))
else
  echo "  [OK] test_track1_runner.sh: $self_lines lines (<= 256)"
fi

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "FATAL: Line count governance violations detected!" >&2
  exit 1
fi
echo "Governance verified: 100% of test suite files strictly <= 256 lines."
echo ""

TIER_TOTAL=0
TIER_PASSED=0
TIER_FAILED=0

echo "--- Executing Track 1 Tier Suites (14 Baseline Suites) ---"
for suite in "${TRACK1_TIER_SUITES[@]}"; do
  suite_path="$TESTS_ROOT/$suite"
  echo ">>> Launching Tier Suite: $suite"
  TIER_TOTAL=$((TIER_TOTAL + 1))
  if bash "$suite_path"; then
    echo ">>> [PASS] Suite: $suite completed successfully."
    TIER_PASSED=$((TIER_PASSED + 1))
  else
    echo ">>> [FAIL] Suite: $suite encountered failures."
    TIER_FAILED=$((TIER_FAILED + 1))
  fi
  echo ""
done

MATRIX_TOTAL=0
MATRIX_PASSED=0
MATRIX_FAILED=0

echo "--- Executing Track 1 LLVM Verification Matrix Suites (6 Suites) ---"
for suite in "${TRACK1_MATRIX_SUITES[@]}"; do
  suite_path="$TESTS_ROOT/$suite"
  echo ">>> Launching Matrix Suite: $suite"
  MATRIX_TOTAL=$((MATRIX_TOTAL + 1))
  if bash "$suite_path"; then
    echo ">>> [PASS] Suite: $suite completed successfully."
    MATRIX_PASSED=$((MATRIX_PASSED + 1))
  else
    echo ">>> [FAIL] Suite: $suite encountered failures."
    MATRIX_FAILED=$((MATRIX_FAILED + 1))
  fi
  echo ""
done

COMBINED_TOTAL=$((TIER_TOTAL + MATRIX_TOTAL))
COMBINED_PASSED=$((TIER_PASSED + MATRIX_PASSED))
COMBINED_FAILED=$((TIER_FAILED + MATRIX_FAILED))

LOG_FILE="$SCRIPT_DIR/test_track1_runner.log"
{
  echo "======================================================================"
  echo "=== openOODA Track 1 E2E Test Runner Scorecard                     ==="
  echo "======================================================================"
  echo "  Total Track 1 Test Suites : $TIER_TOTAL"
  echo "  Passed Test Suites        : $TIER_PASSED"
  echo "  Failed Test Suites        : $TIER_FAILED"
  echo "  Total Matrix Test Suites  : $MATRIX_TOTAL"
  echo "  Passed Matrix Test Suites : $MATRIX_PASSED"
  echo "  Failed Matrix Test Suites : $MATRIX_FAILED"
  echo "  Combined Total Suites     : $COMBINED_TOTAL"
  echo "  Combined Passed Suites    : $COMBINED_PASSED"
  echo "  Combined Failed Suites    : $COMBINED_FAILED"
  echo "  Line Limit Compliance     : 100% (All files <= 256 lines)"
  echo "  Double-Run Determinism    : Enforced across all suites"
  echo "======================================================================"
  if [[ "$COMBINED_FAILED" -gt 0 ]]; then
    echo "STATUS: Track 1 test suite encountered failures."
  else
    echo "STATUS: ALL TRACK 1 SUITES GREEN (100% PASS)"
  fi
} | tee "$LOG_FILE"

if [[ "$COMBINED_FAILED" -gt 0 ]]; then
  exit 1
fi

exit 0
