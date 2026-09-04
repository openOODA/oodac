#!/usr/bin/env bash
# # comb02_headers_and_line_limits.sh — Tier 3: Academy Headers x Line Limits
#
# Logline: Pairwise combination verifying that full 4-element Academy headers
#          coexist within the strict <= 256 lines per file constraint.
#
# Beats:
#   1. Verify header line count overhead remains under 20 lines.
#   2. Verify exact 256-line file with 4-element header compiles.
#   3. Scan repository: files near 256 lines maintain compliant headers.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 02 - Academy Headers x Line Limits"

# Test C2.1: Header overhead on boundary fixture is <= 20 lines
HEADER_LINES=$(head -n 25 "$TESTS_DIR/fixtures/boundary_256_lines.oo" | grep -c "^//" || echo 0)
assert_le "$HEADER_LINES" 20 \
  "C2.1 Academy header overhead ($HEADER_LINES lines) is <= 20 lines"

# Test C2.2: 256-line file with complete header passes typecheck
OUT_C2_2=$("$OODA_BIN" check "$TESTS_DIR/fixtures/boundary_256_lines.oo" 2>&1)
RC_C2_2=$?
assert_exit_code 0 $RC_C2_2 \
  "C2.2 File at exact 256-line ceiling with 4-element header compiles cleanly"

# Test C2.3: Repository scan - largest files adhere to header rule
LARGEST_FILE=$(find "$REPO_ROOT" -name "*.oo" ! -path "*/.agents/*" \
  ! -path "*/tests/fixtures/boundary_257_lines.oo" -exec wc -l {} + 2>/dev/null | sort -n | tail -n 2 | head -n 1 | awk '{print $2}')
assert_file_exists "$LARGEST_FILE" \
  "C2.3 Located largest compiler source file ($LARGEST_FILE)"
HAS_HEADER=0
head -n 20 "$LARGEST_FILE" | grep -q "^// # " && HAS_HEADER=1
assert_eq 1 $HAS_HEADER \
  "C2.3 Largest file maintains compliant Academy header within line limit"
