#!/usr/bin/env bash
# Master E2E Test Suite Runner for openOODA/oodac
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

export OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
export OODA_COMPILER="${OODA_COMPILER:-$OODAC_BIN}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$(cd "$PROJECT_ROOT/.." && pwd -P)}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"

echo "======================================================================"
echo "=== openOODA/oodac Master End-to-End (E2E) Test Suite Runner       ==="
echo "======================================================================"
echo "Target Compiler : $OODAC_BIN"
echo "Project Root    : $PROJECT_ROOT"
echo "Execution Time  : $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

SUITE_LIST=(
  "test_tier1_r1_anchor.sh"
  "test_tier1_r2_migrate.sh"
  "test_tier1_r4_llvm.sh"
  "test_wasm_proving.sh"
  "test_rocm_proving.sh"
  "test_llvm_ir_props.sh"
  "test_llvm_cap_require.sh"
  "test_llvm_struct_capname.sh"
  "test_llvm_resbool.sh"
  "test_llvm_resfloat.sh"
  "test_cli_json_errors.sh"
  "test_llvm_rpath.sh"
  "test_tier1_r3_qa.sh"
  "test_tier1_r5_boot.sh"
  "test_tier2_boundary.sh"
  "test_size_memory_budgets.sh"
  "test_tier3_cross.sh"
  "test_tier4_realworld.sh"
  "test_polyrepo_parity.sh"
  "test_tui_harness.sh"
  "test_installer_updater.sh"
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

self_lines=$(wc -l < "$0")
if [[ "$self_lines" -gt 256 ]]; then
  echo "  [VIOLATION] run_all.sh has $self_lines lines (>256)"
  LINE_VIOLATIONS=$((LINE_VIOLATIONS + 1))
else
  echo "  [OK] run_all.sh: $self_lines lines (<= 256)"
fi

if [[ "$LINE_VIOLATIONS" -gt 0 ]]; then
  echo "FATAL: Line count governance violations detected!" >&2
  exit 1
fi
echo "Governance verified: 100% of test suite files strictly <= 256 lines."
echo ""

# Execution of All Tiers
for suite in "${SUITE_LIST[@]}"; do
  suite_path="$SCRIPT_DIR/$suite"
  echo ">>> Launching Suite: $suite"
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

# Final Consolidated Scorecard
echo "======================================================================"
echo "=== openOODA/oodac E2E Master Scorecard                            ==="
echo "======================================================================"
echo "  Total Test Suites Executed : $TOTAL_SUITES"
echo "  Passed Test Suites         : $PASSED_SUITES"
echo "  Suites with Pending Regs   : $FAILED_SUITES"
echo "  Line Limit Compliance      : 100% (All files <= 256 lines)"
echo "  Double-Run Determinism     : Enforced across all suites"
echo "======================================================================"

if [[ "$FAILED_SUITES" -gt 0 ]]; then
  echo "STATUS: Test suite executed with pending milestone implementations."
  echo "Escalations mapped to implementing agents (M1, M2, M3)."
  exit 1
fi

echo "STATUS: ALL SUITES GREEN (100% PASS)"
exit 0
