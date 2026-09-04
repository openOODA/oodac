#!/usr/bin/env bash
# # comb03_subsystems_and_shims.sh — Tier 3: Dead Subsystems x Shim Elimination
#
# Logline: Pairwise combination testing that dead subsystems and transitional
#          shims do not create circular dependency leaks across backends.
#
# Beats:
#   1. Verify no active backend imports dead defense subsystem.
#   2. Verify x86 emitter does not rely on deleted PGO shims.
#   3. Verify C emitter compiles standalone without transitional shims.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 03 - Dead Subsystems x Shim Elimination"

# Test C3.1: No active backend imports defense/
BACKEND_DEFENSE_IMPORTS=$(grep -rn 'import "defense/' "$REPO_ROOT/emit" 2>/dev/null | wc -l)
assert_eq 0 "$BACKEND_DEFENSE_IMPORTS" \
  "C3.1 Zero backend emitters import dead defense/ subsystem"

# Test C3.2: x86 emitter does not import cli_build_pgo
X86_PGO_IMPORTS=$(grep -rn 'cli_build_pgo' "$REPO_ROOT/emit/x86" 2>/dev/null | wc -l)
assert_eq 0 "$X86_PGO_IMPORTS" \
  "C3.2 x86 emitter contains zero dependencies on cli_build_pgo"

# Test C3.3: Standalone backend module typechecks cleanly
OUT_C3_3=$("$OODA_BIN" check "$REPO_ROOT/emit/x86/ANCHOR.oo" 2>&1)
RC_C3_3=$?
assert_exit_code 0 $RC_C3_3 \
  "C3.3 emit/x86/ANCHOR.oo compiles cleanly without relying on dead subsystems"
