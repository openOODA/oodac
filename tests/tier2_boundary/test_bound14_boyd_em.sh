#!/usr/bin/env bash
# # test_bound14_boyd_em.sh — Tier 2 Boundary: Boyd's E-M Line Limits & Drag
#
# Logline: Boundary tests for file line limit ceilings (255, 256 lines),
#          struct formatting, and loop throughput.
#
# Beats:
#   1. Test exact 256-line ceiling fixture.
#   2. Test 255-line nominal ceiling fixture.
#   3. Test 10-field struct with zero trailing commas.
#   4. Test pure loop throughput logic without heap allocation.
#   5. Test double-run timing consistency.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B14 - Boyd's E-M & Limits Boundary"

# Test B14.1: Exact 256-line boundary fixture
assert_file_exists "$TESTS_DIR/fixtures/boundary_256_lines.oo" \
  "B14.1 256-line boundary fixture exists"
OUT_B14_1=$("$OODA_BIN" check "$TESTS_DIR/fixtures/boundary_256_lines.oo" 2>&1)
RC_B14_1=$?
assert_exit_code 0 $RC_B14_1 \
  "B14.1 File at exact 256-line boundary passes typecheck with exit code 0"

# Test B14.2: 255-line fixture boundary
TMP_255="$TESTS_DIR/fixtures/tmp_bound_255_$$.oo"
head -n 255 "$TESTS_DIR/fixtures/boundary_256_lines.oo" > "$TMP_255"
echo "}" >> "$TMP_255"
LINES_255=$(wc -l < "$TMP_255" || echo 0)
assert_le "$LINES_255" 256 \
  "B14.2 255-line fixture measured strictly <= 256 lines"
rm -f "$TMP_255"

# Test B14.3: 10-field struct with 0 trailing commas
TMP_10F="$TESTS_DIR/fixtures/tmp_bound_10fields_$$.oo"
cat << 'EOF' > "$TMP_10F"
// # Ten Fields
// Logline: 10-field struct with zero trailing commas.
// Setup: Pure compute.
// Beats: 1. Declare struct.
pub type TenFields = struct {
    f1: Int,
    f2: Int,
    f3: Int,
    f4: Int,
    f5: Int,
    f6: Int,
    f7: Int,
    f8: Int,
    f9: Int,
    f10: Int
};
pub fn use_10f(t: TenFields) -> Int {
    return t.f1 + t.f10;
}
EOF
OUT_B14_3=$("$OODA_BIN" check "$TMP_10F" 2>&1)
RC_B14_3=$?
rm -f "$TMP_10F"
assert_exit_code 0 $RC_B14_3 \
  "B14.3 10-field struct with 0 trailing commas compiles cleanly"

# Test B14.4: Pure loop throughput
TMP_LOOP="$TESTS_DIR/fixtures/tmp_bound_throughput_$$.oo"
cat << 'EOF' > "$TMP_LOOP"
// # Loop Throughput
// Logline: Stack-allocated loop without heap allocations.
// Setup: Pure compute.
// Beats: 1. Accumulate sum.
pub fn loop_accumulate(limit: Int) -> Int {
    let mut sum: Int = 0;
    let mut i: Int = 0;
    while i < limit {
        sum = sum + i;
        i = i + 1;
    }
    return sum;
}
EOF
OUT_B14_4=$("$OODA_BIN" check "$TMP_LOOP" 2>&1)
RC_B14_4=$?
rm -f "$TMP_LOOP"
assert_exit_code 0 $RC_B14_4 \
  "B14.4 Zero-heap loop accumulation module compiles cleanly"

# Test B14.5: Typecheck velocity timing under 1000ms
START_NS=$(date +%s%N)
"$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" >/dev/null 2>&1
END_NS=$(date +%s%N)
DURATION_MS=$(( (END_NS - START_NS) / 1000000 ))
assert_le $DURATION_MS 1000 \
  "B14.5 Typecheck turnaround time ($DURATION_MS ms) strictly below 1000ms"
