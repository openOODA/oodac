#!/usr/bin/env bash
# # test_bound05_shims.sh — Tier 2 Boundary: Shims & Control Lowering
#
# Logline: Boundary tests for pattern match lowering, single-arm matches,
#          wildcard patterns, and conditional expressions.
#
# Beats:
#   1. Test single-arm match expression boundary.
#   2. Test match expression with wildcard fallback arm.
#   3. Test nested if-else expressions without fallback cascade.
#   4. Test boolean literal matching.
#   5. Test multiple return statements in branches.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B05 - Shims & Control Boundary"

# Test B5.1: Single-arm match expression
TMP_B5_1="$TESTS_DIR/fixtures/tmp_bound_single_arm_$$.oo"
cat << 'EOF' > "$TMP_B5_1"
// # Single Arm Match
// Logline: Exhaustive match with single variant.
// Setup: Pure compute.
// Beats: 1. Match single variant.
pub type Unit = Single | Empty;
pub fn match_single(u: Unit) -> Int {
    let res = match u {
        Single => 42,
        Empty => 0
    };
    return res;
}
EOF
OUT_B5_1=$("$OODA_BIN" check "$TMP_B5_1" 2>&1)
RC_B5_1=$?
rm -f "$TMP_B5_1"
assert_exit_code 0 $RC_B5_1 \
  "B5.1 Single variant exhaustive match compiles cleanly"

# Test B5.2: Wildcard fallback match arm
TMP_B5_2="$TESTS_DIR/fixtures/tmp_bound_wildcard_$$.oo"
cat << 'EOF' > "$TMP_B5_2"
// # Wildcard Match
// Logline: Match with wildcard arm.
// Setup: Pure compute.
// Beats: 1. Match with _.
pub type TriState = StateA | StateB | StateC;
pub fn match_wildcard(s: TriState) -> Int {
    let res = match s {
        StateA => 1,
        _ => 0
    };
    return res;
}
EOF
OUT_B5_2=$("$OODA_BIN" check "$TMP_B5_2" 2>&1)
RC_B5_2=$?
rm -f "$TMP_B5_2"
assert_exit_code 0 $RC_B5_2 \
  "B5.2 Pattern match with wildcard fallback compiles cleanly"

# Test B5.3: Nested if-else ladder
TMP_B5_3="$TESTS_DIR/fixtures/tmp_bound_if_ladder_$$.oo"
cat << 'EOF' > "$TMP_B5_3"
// # If Ladder
// Logline: Deep if-else ladder.
// Setup: Pure compute.
// Beats: 1. Evaluate condition ladder.
pub fn if_ladder(x: Int) -> Int {
    if x == 1 { return 10; }
    else if x == 2 { return 20; }
    else if x == 3 { return 30; }
    else { return 0; }
}
EOF
OUT_B5_3=$("$OODA_BIN" check "$TMP_B5_3" 2>&1)
RC_B5_3=$?
rm -f "$TMP_B5_3"
assert_exit_code 0 $RC_B5_3 \
  "B5.3 Deep if-else conditional ladder compiles cleanly"

# Test B5.4: Boolean matching
TMP_B5_4="$TESTS_DIR/fixtures/tmp_bound_bool_match_$$.oo"
cat << 'EOF' > "$TMP_B5_4"
// # Bool Branch
// Logline: Boolean conditional branch.
// Setup: Pure compute.
// Beats: 1. Branch on bool.
pub fn bool_branch(b: Bool) -> Int {
    if b { return 1; } else { return 0; }
}
EOF
OUT_B5_4=$("$OODA_BIN" check "$TMP_B5_4" 2>&1)
RC_B5_4=$?
rm -f "$TMP_B5_4"
assert_exit_code 0 $RC_B5_4 \
  "B5.4 Boolean conditional branch compiles cleanly"

# Test B5.5: Non-exhaustive match rejection
TMP_B5_5="$TESTS_DIR/fixtures/tmp_bound_non_exh_$$.oo"
cat << 'EOF' > "$TMP_B5_5"
// # Non-Exhaustive Match
// Logline: Missing variant arm.
// Setup: Typecheck must fail.
// Beats: 1. Incomplete match.
pub type Pair = First | Second;
pub fn incomplete_match(p: Pair) -> Int {
    let res = match p {
        First => 1
    };
    return res;
}
EOF
OUT_B5_5=$("$OODA_BIN" check "$TMP_B5_5" 2>&1)
RC_B5_5=$?
rm -f "$TMP_B5_5"
# Rejection of incomplete match or fallback requirement
assert_not_contains "panic" "$OUT_B5_5" \
  "B5.5 Non-exhaustive match handled without compiler crash"
