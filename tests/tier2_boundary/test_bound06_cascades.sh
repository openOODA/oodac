#!/usr/bin/env bash
# # test_bound06_cascades.sh — Tier 2 Boundary: Cascades & CLI Parsing
#
# Logline: Boundary tests for CLI argument parsing, empty paths, trailing slashes,
#          and unknown flags handling.
#
# Beats:
#   1. Test empty path string parameter.
#   2. Test trailing slash path resolution.
#   3. Test relative dot prefix path resolution.
#   4. Test CLI driver with no arguments.
#   5. Test unknown CLI argument rejection.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B06 - Cascades & CLI Boundary"

# Test B6.1: Empty path string parameter fails closed
OUT_B6_1=$("$OODA_BIN" check "" 2>&1)
RC_B6_1=$?
assert_exit_code 2 $RC_B6_1 \
  "B6.1 Empty file path argument fails closed with usage exit code 2"

# Test B6.2: Trailing slash on non-directory fails closed
OUT_B6_2=$("$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo/" 2>&1)
RC_B6_2=$?
assert_exit_code 2 $RC_B6_2 \
  "B6.2 File path with invalid trailing slash fails closed"

# Test B6.3: Relative dot prefix path resolution
CUR_DIR=$(pwd)
cd "$TESTS_DIR/fixtures"
OUT_B6_3=$("$OODA_BIN" check "./valid_minimal.oo" 2>&1)
RC_B6_3=$?
cd "$CUR_DIR"
assert_exit_code 0 $RC_B6_3 \
  "B6.3 Path with ./ prefix resolves cleanly"

# Test B6.4: CLI driver with zero arguments emits usage and exit 2
OUT_B6_4=$("$OODA_BIN" 2>&1)
RC_B6_4=$?
assert_exit_code 2 $RC_B6_4 \
  "B6.4 CLI invocation with 0 arguments emits usage and exits 2"
assert_contains "usage:" "$OUT_B6_4" \
  "B6.4 Emits usage documentation string"

# Test B6.5: Unknown CLI argument rejection
OUT_B6_5=$("$OODA_BIN" --totally-invalid-flag-123 "$TESTS_DIR/fixtures/valid_minimal.oo" 2>&1)
RC_B6_5=$?
assert_exit_code 2 $RC_B6_5 \
  "B6.5 Unknown CLI options fail closed with exit code 2"
