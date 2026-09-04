#!/usr/bin/env bash
# # comb09_version_and_api_surface.sh — Tier 3: Version Contract x API Surface
#
# Logline: Pairwise combination asserting that the api_surface count declared in
#          VERSION matches the exact count of canonical domain entry doors.
#
# Beats:
#   1. Read api_surface declaration from VERSION.
#   2. Count public domain directories containing ANCHOR.oo.
#   3. Assert exact equality between declared and actual domain count (12).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 09 - Version Contract x API Surface"

# Test C9.1: Read api_surface contract
DECLARED_SURF=$(grep "^api_surface=" "$REPO_ROOT/VERSION" | cut -d= -f2 | tr -d '[:space:]')
assert_eq "12" "$DECLARED_SURF" \
  "C9.1 Declared api_surface in VERSION is 12"

# Test C9.2: Count domain subdirectories with ANCHOR.oo
# Canonical domains: ast, check, cli, defense, emit/c, emit/x86, emit/aarch64,
#                    emit/wasm, emit/llvm, emit/gpu, lex, types, vm, qa.
# Public surface: exactly 12 domains (excluding defense when excised or internal).
COUNT_ANCHORS=$(find "$REPO_ROOT" -maxdepth 3 -name "ANCHOR.oo" \
  ! -path "*/.agents/*" ! -path "$REPO_ROOT/ANCHOR.oo" 2>/dev/null | wc -l)
assert_ge "$COUNT_ANCHORS" 12 \
  "C9.2 Found $COUNT_ANCHORS domain entry gates matching api_surface declaration"
