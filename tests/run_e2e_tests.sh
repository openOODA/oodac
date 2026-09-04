#!/usr/bin/env bash
# # run_e2e_tests.sh — Sovereign oodac Compiler Core E2E Test Suite Runner
#
# Logline: Orchestrates comprehensive execution of Tiers 1-4 opaque-box E2E
#          tests, collecting results, checking determinism, and reporting metrics.
#
# Beats:
#   1. Parse options (--double-run, --tier, --help).
#   2. Execute Tier 1: Feature Coverage suites (Features 1-17).
#   3. Execute Tier 2: Boundary & Corner suites (Features 1-17).
#   4. Execute Tier 3: Cross-Feature Combination suites.
#   5. Execute Tier 4: Real-World Application scenarios.
#   6. Emit consolidated test report and return exit code.

set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR="$SCRIPT_DIR"
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

# Check prerequisites
if [[ ! -x "$OODA_BIN" ]]; then
  echo "Error: ooda binary not executable at $OODA_BIN" >&2
  exit 2
fi

RUN_TIER="all"
DOUBLE_RUN=0

for arg in "$@"; do
  case "$arg" in
    all|tier1|tier2|tier3|tier4)
      RUN_TIER="$arg"
      ;;
    --double-run)
      DOUBLE_RUN=1
      ;;
    -h|--help)
      echo "Usage: ./tests/run_e2e_tests.sh [all|tier1|tier2|tier3|tier4] [--double-run]"
      exit 0
      ;;
  esac
done

echo "================================================================"
echo " Sovereign oodac Compiler Core — E2E Test Suite"
echo " Target Workspace: $REPO_ROOT"
echo " Toolchain Driver: $OODA_BIN"
echo " Execution Mode:   Tier Selection = $RUN_TIER"
echo " Double-Run Mode:  $([ "$DOUBLE_RUN" -eq 1 ] && echo 'ENABLED' || echo 'DISABLED')"
echo "================================================================"

SUITE_START=$(date +%s)
TOTAL_PASSED=0
TOTAL_FAILED=0
SUITES_RUN=0
SUITES_FAILED=0

run_test_script() {
  local script="$1"
  local sname
  sname=$(basename "$script")
  SUITES_RUN=$((SUITES_RUN + 1))
  
  # Execute script and capture output
  local out
  out=$("$script" 2>&1)
  local rc=$?
  
  # Parse test counts from output
  local passed
  passed=$(echo "$out" | grep -c "\[PASS\]" || true)
  local failed
  failed=$(echo "$out" | grep -c "\[FAIL\]" || true)
  
  TOTAL_PASSED=$((TOTAL_PASSED + passed))
  TOTAL_FAILED=$((TOTAL_FAILED + failed))
  
  if [[ $rc -ne 0 || $failed -gt 0 ]]; then
    SUITES_FAILED=$((SUITES_FAILED + 1))
    echo -e "  \033[0;31m[FAIL]\033[0m $sname (passed: $passed, failed: $failed)"
    echo "$out" | grep "\[FAIL\]" | sed 's/^/    /'
  else
    echo -e "  \033[0;32m[PASS]\033[0m $sname (passed: $passed, failed: 0)"
  fi
}

# Tier 1: Feature Coverage (Features 1-17)
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "tier1" ]]; then
  echo ""
  echo "--- Executing Tier 1: Feature Coverage (Features 1-17) ---"
  for s in "$TESTS_DIR"/tier1_features/test_feat*.sh; do
    [[ -f "$s" ]] && run_test_script "$s"
  done
fi

# Tier 2: Boundary & Corner Cases (Features 1-17)
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "tier2" ]]; then
  echo ""
  echo "--- Executing Tier 2: Boundary & Corner Cases (Features 1-17) ---"
  for s in "$TESTS_DIR"/tier2_boundary/test_bound*.sh; do
    [[ -f "$s" ]] && run_test_script "$s"
  done
fi

# Tier 3: Cross-Feature Combinations
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "tier3" ]]; then
  echo ""
  echo "--- Executing Tier 3: Cross-Feature Combinations ---"
  for s in "$TESTS_DIR"/tier3_combinations/comb*.sh; do
    [[ -f "$s" ]] && run_test_script "$s"
  done
fi

# Tier 4: Real-World Application Scenarios
if [[ "$RUN_TIER" == "all" || "$RUN_TIER" == "tier4" ]]; then
  echo ""
  echo "--- Executing Tier 4: Real-World Applications ---"
  for s in "$TESTS_DIR"/tier4_realworld/test_*.sh; do
    [[ -f "$s" ]] && run_test_script "$s"
  done
fi

# Double-Run Determinism Invariant Verification
if [[ "$DOUBLE_RUN" -eq 1 ]]; then
  echo ""
  echo "--- Verifying Double-Run Determinism Invariant (Run 2) ---"
  D_RUN1=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
  D_RUN2=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
  if [[ "$D_RUN1" == "$D_RUN2" ]]; then
    echo -e "  \033[0;32m[PASS]\033[0m Double-run bit-identical output certified"
  else
    echo -e "  \033[0;31m[FAIL]\033[0m Double-run variance detected"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
  fi
fi

SUITE_END=$(date +%s)
DURATION=$((SUITE_END - SUITE_START))

echo ""
echo "================================================================"
echo " Consolidated Test Execution Summary"
echo "================================================================"
echo " Total Test Suites: $SUITES_RUN (Failed Suites: $SUITES_FAILED)"
echo " Total Test Cases:  $((TOTAL_PASSED + TOTAL_FAILED))"
echo -e " Passed Cases:      \033[0;32m$TOTAL_PASSED\033[0m"
if [[ $TOTAL_FAILED -gt 0 ]]; then
  echo -e " Failed Cases:      \033[0;31m$TOTAL_FAILED\033[0m"
else
  echo -e " Failed Cases:      \033[0;32m0\033[0m"
fi
echo " Total Duration:    ${DURATION}s"
echo "================================================================"

if [[ $TOTAL_FAILED -gt 0 || $SUITES_FAILED -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
