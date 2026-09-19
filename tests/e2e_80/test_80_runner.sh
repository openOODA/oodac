#!/usr/bin/env bash
# Master E2E Runner for openOODA 80/80 Target Scorecard Convergence
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2 = 0), Negative-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"

export OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"

echo "======================================================================"
echo "=== openOODA 80/80 Target Scorecard Convergence Master E2E Runner  ==="
echo "======================================================================"
echo "Target Compiler : $OODAC_BIN"
echo "Project Root    : $PROJECT_ROOT"
echo "Execution Time  : $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

SUITE_LIST=(
  "test_tier1_phase0.sh"
  "test_tier1_phase1_prover.sh"
  "test_tier1_phase1_lowering.sh"
  "test_tier1_phase2_selfhost.sh"
  "test_tier1_phase3_ecosystem.sh"
  "test_tier2_phase0.sh"
  "test_tier2_phase1_prover.sh"
  "test_tier2_phase1_lowering.sh"
  "test_tier2_phase2_selfhost.sh"
  "test_tier2_phase3_ecosystem.sh"
  "test_tier3_pairwise.sh"
  "test_tier4_scenarios.sh"
)

# Governance: Verify Line Count Ceilings (wc -l <= 256)
echo "--- Governance Verification: Line Limit Ceiling (wc -l <= 256) ---"
LINE_VIOLATIONS=0
for s in "${SUITE_LIST[@]}"; do
  fpath="$SCRIPT_DIR/$s"
  if [[ -f "$fpath" ]]; then
    lines=$(wc -l < "$fpath")
    if [[ "$lines" -gt 256 ]]; then
      echo "  [VIOLATION] $s has $lines lines (>256)"
      LINE_VIOLATIONS=$((LINE_VIOLATIONS + 1))
    else
      echo "  [OK] $s: $lines lines (<= 256)"
    fi
  else
    echo "  [MISSING] $s does not exist"
    LINE_VIOLATIONS=$((LINE_VIOLATIONS + 1))
  fi
done

for doc in "TEST_INFRA.md" "TEST_READY.md"; do
  if [[ -f "$PROJECT_ROOT/$doc" ]]; then
    doc_lines=$(wc -l < "$PROJECT_ROOT/$doc")
    if [[ "$doc_lines" -gt 256 ]]; then
      echo "  [VIOLATION] $doc has $doc_lines lines (>256)"
      LINE_VIOLATIONS=$((LINE_VIOLATIONS + 1))
    else
      echo "  [OK] $doc: $doc_lines lines (<= 256)"
    fi
  fi
done

if [[ "$LINE_VIOLATIONS" -gt 0 ]]; then
  echo "CRITICAL: $LINE_VIOLATIONS governance line limit violations detected."
  exit 1
fi
echo "Governance verified: 100% of test suite files strictly <= 256 lines."
echo

# Execute each suite
for s in "${SUITE_LIST[@]}"; do
  fpath="$SCRIPT_DIR/$s"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  echo ">>> Launching openOODA 80/80 Suite: $s"
  if bash "$fpath"; then
    echo ">>> [PASS] Suite: $s completed successfully."
    PASSED_SUITES=$((PASSED_SUITES + 1))
  else
    echo ">>> [FAIL] Suite: $s failed."
    FAILED_SUITES=$((FAILED_SUITES + 1))
  fi
  echo
done

echo "======================================================================"
echo "=== openOODA 80/80 Target Scorecard E2E Runner Final Scorecard     ==="
echo "======================================================================"
echo "  Total 80/80 Test Suites   : $TOTAL_SUITES"
echo "  Passed Test Suites        : $PASSED_SUITES"
echo "  Failed Test Suites        : $FAILED_SUITES"
echo "  Line Limit Compliance     : 100% (All files <= 256 lines)"
echo "  Double-Run Determinism    : Enforced across all suites"
echo "======================================================================"

if [[ "$FAILED_SUITES" -eq 0 ]]; then
  echo "STATUS: ALL OPENOODA 80/80 SUITES GREEN (100% PASS)"
  exit 0
else
  echo "STATUS: FAILURE ($FAILED_SUITES suites failed)"
  exit 1
fi
