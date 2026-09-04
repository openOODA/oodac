#!/usr/bin/env bash
# # test_feat03_typecheck_assurance.sh — Feature 3: Domain Typecheck Assurance
#
# Logline: Verifies that domain front doors and valid typed sources
#          pass ooda check cleanly, and type mismatches fail closed.
#
# Beats:
#   1. Verify lex/ANCHOR.oo typecheck passes.
#   2. Verify qa/ANCHOR.oo typecheck passes.
#   3. Verify qa/probe_api_surface.oo typecheck passes.
#   4. Verify valid typed fixture compiles cleanly.
#   5. Verify type mismatch fails closed with diagnostic error.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "03 - Domain Typecheck Assurance"

# Test 3.1: lex/ANCHOR.oo domain door
OUT_3_1=$("$OODA_BIN" check "$REPO_ROOT/lex/ANCHOR.oo" 2>&1)
RC_3_1=$?
assert_exit_code 0 $RC_3_1 \
  "3.1 lex/ANCHOR.oo domain front door passes ooda check cleanly"

# Test 3.2: qa/ANCHOR.oo domain door
OUT_3_2=$("$OODA_BIN" check "$REPO_ROOT/qa/ANCHOR.oo" 2>&1)
RC_3_2=$?
assert_exit_code 0 $RC_3_2 \
  "3.2 qa/ANCHOR.oo domain front door passes ooda check cleanly"

# Test 3.3: qa/probe_api_surface.oo
OUT_3_3=$("$OODA_BIN" check "$REPO_ROOT/qa/probe_api_surface.oo" 2>&1)
RC_3_3=$?
assert_exit_code 0 $RC_3_3 \
  "3.3 qa/probe_api_surface.oo passes ooda check cleanly"

# Test 3.4: Valid typed fixture
OUT_3_4=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
RC_3_4=$?
assert_exit_code 0 $RC_3_4 \
  "3.4 Valid typed source fixture passes typecheck"

# Test 3.5: Type mismatch fails closed
OUT_3_5=$("$OODA_BIN" check "$TESTS_DIR/fixtures/invalid_type.oo" 2>&1)
RC_3_5=$?
assert_exit_code 1 $RC_3_5 \
  "3.5 Type mismatch fails closed with non-zero exit code"
