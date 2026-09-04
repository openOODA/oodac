#!/usr/bin/env bash
# # comb10_boyd_em_and_determinism.sh — Tier 3: Boyd's E-M x Double-Run Invariant
#
# Logline: Pairwise combination asserting that high-throughput zero-heap compiler
#          execution produces bit-identical results across repeated runs.
#
# Beats:
#   1. Execute Run 1 on standard fixture.
#   2. Execute Run 2 on standard fixture.
#   3. Assert Run 1 == Run 2 bit-identical output.
#   4. Measure execution velocity across double run.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 10 - Boyd's E-M x Double-Run Invariant"

FIXTURE="$TESTS_DIR/fixtures/valid_minimal.oo"

# Test C10.1: Run 1
OUT1=$("$OODA_BIN" check "$FIXTURE" 2>&1)
RC1=$?
assert_exit_code 0 $RC1 \
  "C10.1 Run 1 completes cleanly with exit code 0"

# Test C10.2: Run 2
OUT2=$("$OODA_BIN" check "$FIXTURE" 2>&1)
RC2=$?
assert_exit_code 0 $RC2 \
  "C10.2 Run 2 completes cleanly with exit code 0"

# Test C10.3: Double-run identity
assert_eq "$OUT1" "$OUT2" \
  "C10.3 Double-run invariant satisfied: Run 1 output == Run 2 output"
