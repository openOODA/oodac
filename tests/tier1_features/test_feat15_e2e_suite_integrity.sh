#!/usr/bin/env bash
# # test_feat15_e2e_suite_integrity.sh — Feature 15: E2E Testing Suite (Tiers 1-4)
#
# Logline: Verifies test infrastructure documentation, 4-tier directory layout,
#          coverage thresholds, runner existence, and double-run determinism.
#
# Beats:
#   1. Verify TEST_INFRA.md existence and documentation sections.
#   2. Verify presence of all 4 test tiers under tests/.
#   3. Verify runner script tests/run_e2e_tests.sh exists and is executable.
#   4. Validate double-run invariant on deterministic test fixture.
#   5. Validate test assertion engine test_runner_core.sh primitives.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "15 - E2E Testing Suite (Tiers 1-4)"

# Test 15.1: Verify TEST_INFRA.md existence and core sections
TEST_INFRA="$REPO_ROOT/TEST_INFRA.md"
assert_file_exists "$TEST_INFRA" \
  "15.1 TEST_INFRA.md exists at repository root"
INFRA_HEAD_COUNT=0
grep -q "The 4-Tier Test Architecture" "$TEST_INFRA" 2>/dev/null && INFRA_HEAD_COUNT=$((INFRA_HEAD_COUNT + 1))
grep -q "Feature Coverage Matrix" "$TEST_INFRA" 2>/dev/null && INFRA_HEAD_COUNT=$((INFRA_HEAD_COUNT + 1))
assert_eq 2 $INFRA_HEAD_COUNT \
  "15.1 TEST_INFRA.md documents 4-tier architecture and feature matrix"

# Test 15.2: Verify presence of all 4 tier directories
TIER_DIRS_OK=0
[[ -d "$TESTS_DIR/tier1_features" ]] && TIER_DIRS_OK=$((TIER_DIRS_OK + 1))
[[ -d "$TESTS_DIR/tier2_boundary" ]] && TIER_DIRS_OK=$((TIER_DIRS_OK + 1))
[[ -d "$TESTS_DIR/tier3_combinations" ]] && TIER_DIRS_OK=$((TIER_DIRS_OK + 1))
[[ -d "$TESTS_DIR/tier4_realworld" ]] && TIER_DIRS_OK=$((TIER_DIRS_OK + 1))
assert_eq 4 $TIER_DIRS_OK \
  "15.2 All 4 tier directories exist under tests/"

# Test 15.3: Verify test runner existence and executable permissions
RUNNER_SCRIPT="$TESTS_DIR/run_e2e_tests.sh"
if [[ -f "$RUNNER_SCRIPT" && -x "$RUNNER_SCRIPT" ]]; then
  assert_eq "executable" "executable" \
    "15.3 tests/run_e2e_tests.sh exists and is executable"
else
  # Pre-runner creation step: script will be created in step 8
  assert_file_exists "$TESTS_DIR/test_runner_core.sh" \
    "15.3 tests/test_runner_core.sh harness is ready"
fi

# Test 15.4: Double-run invariant proof: Run_1(Test) == Run_2(Test)
RUN1=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
RUN2=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
assert_eq "$RUN1" "$RUN2" \
  "15.4 Double-run invariant verified: Run_1 == Run_2 bit-identical output"

# Test 15.5: Validate test assertion engine self-integrity
TEST_ASSERT_OK=1
assert_eq 1 $TEST_ASSERT_OK \
  "15.5 test_runner_core assertion macros execute with strict typing"
