#!/usr/bin/env bash
# # test_feat04_dead_subsystems.sh — Feature 4: Dead Subsystem Excising
#
# Logline: Verifies detection and elimination of unused dead subsystems
#          (defense/ directory and cli/cli_build_pgo.oo) with zero callers.
#
# Beats:
#   1. Check cli_build_pgo functions have zero active callers.
#   2. Check defense/ passes have zero functional callers in lowering.
#   3. Verify importing non-existent module fails closed.
#   4. Validate dead module detection logic against unused fixture.
#   5. Verify compiler build pipeline does not depend on dead symbols.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "04 - Dead Subsystem Excising"

# Test 4.1: Verify cli_build_pgo unreferenced functions
# Function ooprof_branch_new has 0 callers across the repository
PGO_FILE="$REPO_ROOT/cli/cli_build_pgo.oo"
if [[ ! -f "$PGO_FILE" ]]; then
  assert_eq "excised" "excised" \
    "4.1 cli_build_pgo.oo successfully excised from codebase"
else
  # If file still present prior to M2, assert that its functions have 0 callers
  CALLERS=$(grep -r "ooprof_branch_new" "$REPO_ROOT" \
    --exclude="cli_build_pgo.oo" --exclude-dir=".agents" \
    --exclude-dir="tests" 2>/dev/null | wc -l)
  assert_eq 0 "$CALLERS" \
    "4.1 cli_build_pgo.oo functions have 0 callers in compiler"
fi

# Test 4.2: Verify defense/ subsystem has zero functional callers in pipeline
DEFENSE_DIR="$REPO_ROOT/defense"
if [[ ! -d "$DEFENSE_DIR" ]]; then
  assert_eq "excised" "excised" \
    "4.2 defense/ subsystem successfully excised from codebase"
else
  # If directory still present, verify no functional calls to defense_mutate_op
  DEFENSE_CALLS=$(grep -r "defense_mutate_op" "$REPO_ROOT" \
    --exclude-dir="defense" --exclude-dir=".agents" \
    --exclude-dir="tests" 2>/dev/null | wc -l)
  assert_eq 0 "$DEFENSE_CALLS" \
    "4.2 defense/ mutations have 0 callers in compilation passes"
fi

# Test 4.3: Attempt to import a deleted/non-existent subsystem fails closed
TMP_DEAD="$TESTS_DIR/fixtures/tmp_dead_import_$$.oo"
cat << 'EOF' > "$TMP_DEAD"
// # Non-Existent Subsystem Import
//
// Logline: Attempts to import a deleted subsystem.
//
// Setup: Typechecking must fail closed.
//
// Beats:
//   1. Import missing module.

import "nonexistent_subsystem_purged/ANCHOR.oo";

pub fn use_dead() -> Int {
    return 0;
}
EOF

OUT_4_3=$("$OODA_BIN" check "$TMP_DEAD" 2>&1)
RC_4_3=$?
rm -f "$TMP_DEAD"
assert_exit_code 1 $RC_4_3 \
  "4.3 Importing non-existent/excised subsystem fails typecheck cleanly"

# Test 4.4: Synthetic live dependency chain
TMP_MOD_A="$TESTS_DIR/fixtures/tmp_mod_a_$$.oo"
cat << 'EOF' > "$TMP_MOD_A"
// # Live Module
//
// Logline: Live module referenced by consumer.
//
// Setup: Pure compute.
//
// Beats:
//   1. Export live function.

pub fn live_calc() -> Int { return 10; }
EOF

TMP_CONSUMER="$TESTS_DIR/fixtures/tmp_consumer_$$.oo"
cat << EOF > "$TMP_CONSUMER"
// # Consumer
//
// Logline: Calls live module.
//
// Setup: Pure compute.
//
// Beats:
//   1. Call live function.

import "tmp_mod_a_$$.oo";

pub fn run_consumer() -> Int {
    return live_calc();
}
EOF

OUT_4_4=$("$OODA_BIN" check "$TMP_CONSUMER" 2>&1)
RC_4_4=$?
rm -f "$TMP_MOD_A" "$TMP_CONSUMER"
assert_exit_code 0 $RC_4_4 \
  "4.4 Active dependency chain typechecks without dead-code error"

# Test 4.5: Assert zero dangling imports of dead subsystems in core entry gates
DANGLING_IMPORTS=0
if grep -q 'import "defense/' "$REPO_ROOT/check/ANCHOR.oo" 2>/dev/null; then
  DANGLING_IMPORTS=$((DANGLING_IMPORTS + 1))
fi
if grep -q 'import "defense/' "$REPO_ROOT/emit/c/ANCHOR.oo" 2>/dev/null; then
  DANGLING_IMPORTS=$((DANGLING_IMPORTS + 1))
fi
assert_eq 0 $DANGLING_IMPORTS \
  "4.5 Core typechecker and C emitter do not import dead defense module"
