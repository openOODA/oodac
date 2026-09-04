#!/usr/bin/env bash
# # test_bound10_dead_code.sh — Tier 2 Boundary: Dead Code & Encapsulation
#
# Logline: Boundary tests for call graph traversal: recursive functions,
#          chains of private helpers, public exports, and type aliases.
#
# Beats:
#   1. Test private helper call chain preservation.
#   2. Test self-recursive function call graph traversal.
#   3. Test public API function preservation without internal callers.
#   4. Test 5-element private helper cascade called by single public entry.
#   5. Test unused type alias compilation.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B10 - Dead Code & Encapsulation Boundary"

# Test B10.1: Private helper call chain
TMP_B10_1="$TESTS_DIR/fixtures/tmp_bound_chain_$$.oo"
cat << 'EOF' > "$TMP_B10_1"
// # Helper Chain
// Logline: Private helper call chain.
// Setup: Pure compute.
// Beats: 1. Call chain.
fn step_c(v: Int) -> Int { return v + 1; }
fn step_b(v: Int) -> Int { return step_c(v) * 2; }
fn step_a(v: Int) -> Int { return step_b(v) + 3; }
pub fn run_chain(v: Int) -> Int { return step_a(v); }
EOF
OUT_B10_1=$("$OODA_BIN" check "$TMP_B10_1" 2>&1)
RC_B10_1=$?
rm -f "$TMP_B10_1"
assert_exit_code 0 $RC_B10_1 \
  "B10.1 Private helper call chain compiles cleanly without dead-code error"

# Test B10.2: Self-recursive function
TMP_B10_2="$TESTS_DIR/fixtures/tmp_bound_recurse_$$.oo"
cat << 'EOF' > "$TMP_B10_2"
// # Recursive Fn
// Logline: Self-recursive function.
// Setup: Pure compute.
// Beats: 1. Recursively compute factorial.
pub fn fact(n: Int) -> Int {
    if n <= 1 { return 1; }
    return n * fact(n - 1);
}
EOF
OUT_B10_2=$("$OODA_BIN" check "$TMP_B10_2" 2>&1)
RC_B10_2=$?
rm -f "$TMP_B10_2"
assert_exit_code 0 $RC_B10_2 \
  "B10.2 Self-recursive function compiles cleanly"

# Test B10.3: Public API function without internal callers
TMP_B10_3="$TESTS_DIR/fixtures/tmp_bound_pub_no_call_$$.oo"
cat << 'EOF' > "$TMP_B10_3"
// # Uncalled Public
// Logline: Public export without internal callers.
// Setup: Pure compute.
// Beats: 1. Export API.
pub fn library_api_export() -> Int {
    return 1337;
}
EOF
OUT_B10_3=$("$OODA_BIN" check "$TMP_B10_3" 2>&1)
RC_B10_3=$?
rm -f "$TMP_B10_3"
assert_exit_code 0 $RC_B10_3 \
  "B10.3 Public library export without callers in file compiles cleanly"

# Test B10.4: Multiple private helpers called by public entry
TMP_B10_4="$TESTS_DIR/fixtures/tmp_bound_fanout_$$.oo"
cat << 'EOF' > "$TMP_B10_4"
// # Fanout
// Logline: 3 private helpers called by public entry.
// Setup: Pure compute.
// Beats: 1. Call all helpers.
fn h1() -> Int { return 1; }
fn h2() -> Int { return 2; }
fn h3() -> Int { return 3; }
pub fn run_fanout() -> Int {
    return h1() + h2() + h3();
}
EOF
OUT_B10_4=$("$OODA_BIN" check "$TMP_B10_4" 2>&1)
RC_B10_4=$?
rm -f "$TMP_B10_4"
assert_exit_code 0 $RC_B10_4 \
  "B10.4 Multiple private helpers with callers compile cleanly"

# Test B10.5: Unused type declaration
TMP_B10_5="$TESTS_DIR/fixtures/tmp_bound_unused_type_$$.oo"
cat << 'EOF' > "$TMP_B10_5"
// # Unused Type
// Logline: Declares type without usage in functions.
// Setup: Pure compute.
// Beats: 1. Export function.
pub type PassiveRecord = struct {
    tag: Int
};
pub fn active_fn() -> Int { return 0; }
EOF
OUT_B10_5=$("$OODA_BIN" check "$TMP_B10_5" 2>&1)
RC_B10_5=$?
rm -f "$TMP_B10_5"
assert_exit_code 0 $RC_B10_5 \
  "B10.5 Public type declaration in library compiles cleanly"
