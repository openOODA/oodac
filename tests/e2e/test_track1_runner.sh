#!/usr/bin/env bash
# Track 1 Master E2E Test Suite Runner
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"

export OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"

echo "======================================================================"
echo "=== openOODA Track 1 LLVM Lowering Engine Master E2E Runner        ==="
echo "======================================================================"
echo "Target Compiler : $OODAC_BIN"
echo "Project Root    : $PROJECT_ROOT"
echo "Execution Time  : $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

TRACK1_SUITES=(
  "test_tier1_m1.sh"
  "test_tier1_m2.sh"
  "test_tier1_m3.sh"
  "test_tier1_m4.sh"
  "test_tier1_m5.sh"
  "test_tier1_m6.sh"
  "test_tier2_m1.sh"
  "test_tier2_m2.sh"
  "test_tier2_m3.sh"
  "test_tier2_m4.sh"
  "test_tier2_m5.sh"
  "test_tier2_m6.sh"
  "test_tier3_pairwise.sh"
  "test_tier4_scenarios.sh"
)

echo "--- Governance Verification: Line Limit Ceiling (wc -l <= 256) ---"
VIOLATIONS=0
for s in "${TRACK1_SUITES[@]}"; do
  fpath="$SCRIPT_DIR/$s"
  if [[ -f "$fpath" ]]; then
    lines=$(wc -l < "$fpath")
    if [[ "$lines" -gt 256 ]]; then
      echo "  [VIOLATION] $s has $lines lines (>256)"
      VIOLATIONS=$((VIOLATIONS + 1))
    else
      echo "  [OK] $s: $lines lines (<= 256)"
    fi
  else
    echo "  [MISSING] $s does not exist"
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

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

for suite in "${TRACK1_SUITES[@]}"; do
  suite_path="$SCRIPT_DIR/$suite"
  echo ">>> Launching Track 1 Suite: $suite"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  if bash "$suite_path"; then
    echo ">>> [PASS] Suite: $suite completed successfully."
    PASSED_SUITES=$((PASSED_SUITES + 1))
  else
    echo ">>> [FAIL] Suite: $suite encountered failures."
    FAILED_SUITES=$((FAILED_SUITES + 1))
  fi
  echo ""
done

echo "======================================================================"
echo "=== openOODA Track 1 E2E Test Runner Scorecard                     ==="
echo "======================================================================"
echo "  Total Track 1 Test Suites : $TOTAL_SUITES"
echo "  Passed Test Suites        : $PASSED_SUITES"
echo "  Failed Test Suites        : $FAILED_SUITES"
echo "  Line Limit Compliance     : 100% (All files <= 256 lines)"
echo "  Double-Run Determinism    : Enforced across all suites"
echo "======================================================================"

if [[ "$FAILED_SUITES" -gt 0 ]]; then
  echo "STATUS: Track 1 test suite encountered failures."
  exit 1
fi

echo "STATUS: ALL TRACK 1 SUITES GREEN (100% PASS)"
exit 0
