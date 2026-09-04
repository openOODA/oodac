#!/usr/bin/env bash
# # test_bound02_academy_headers.sh — Tier 2 Boundary: Academy Headers
#
# Logline: Tests boundary conditions for Academy headers: minimal length,
#          extreme length, single beat, 16 beats, and special punctuation.
#
# Beats:
#   1. Test minimal 1-character field values.
#   2. Test extreme long single-line logline.
#   3. Test single beat header boundary.
#   4. Test 16-beat header boundary.
#   5. Test special punctuation in Title.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B02 - Academy Headers Boundary"

# Test B2.1: Minimal 1-character fields
TMP_B2_1="$TESTS_DIR/fixtures/tmp_bound_min_header_$$.oo"
cat << 'EOF' > "$TMP_B2_1"
// # A
// Logline: B
// Setup: C
// Beats:
//   1. D
pub fn min_header_fn() -> Int { return 1; }
EOF
OUT_B2_1=$("$OODA_BIN" check "$TMP_B2_1" 2>&1)
RC_B2_1=$?
rm -f "$TMP_B2_1"
assert_exit_code 0 $RC_B2_1 \
  "B2.1 Minimal 1-character Academy header fields compile cleanly"

# Test B2.2: Extreme long logline (500 characters)
LONG_DESC=$(python3 -c 'print("A" * 500)')
TMP_B2_2="$TESTS_DIR/fixtures/tmp_bound_long_logline_$$.oo"
cat << EOF > "$TMP_B2_2"
// # Long Logline Test
// Logline: $LONG_DESC
// Setup: Pure compute.
// Beats:
//   1. Run fn.
pub fn long_logline_fn() -> Int { return 2; }
EOF
OUT_B2_2=$("$OODA_BIN" check "$TMP_B2_2" 2>&1)
RC_B2_2=$?
rm -f "$TMP_B2_2"
assert_exit_code 0 $RC_B2_2 \
  "B2.2 Extreme length logline boundary compiles cleanly"

# Test B2.3: Single Beat boundary
TMP_B2_3="$TESTS_DIR/fixtures/tmp_bound_single_beat_$$.oo"
cat << 'EOF' > "$TMP_B2_3"
// # Single Beat
// Logline: Valid single beat.
// Setup: Pure compute.
// Beats:
//   1. Sole beat in module.
pub fn single_beat_fn() -> Int { return 3; }
EOF
OUT_B2_3=$("$OODA_BIN" check "$TMP_B2_3" 2>&1)
RC_B2_3=$?
rm -f "$TMP_B2_3"
assert_exit_code 0 $RC_B2_3 \
  "B2.3 Single numbered beat header boundary compiles cleanly"

# Test B2.4: 16 Numbered Beats boundary
TMP_B2_4="$TESTS_DIR/fixtures/tmp_bound_16_beats_$$.oo"
python3 -c '
header = """// # 16 Beats Test
// Logline: Module with 16 distinct beats.
// Setup: Pure compute.
// Beats:
"""
beats = "\n".join([f"//   {i}. Beat number {i}." for i in range(1, 17)])
footer = """
pub fn multi_beat_fn() -> Int { return 4; }
"""
with open("'"$TMP_B2_4"'", "w") as f:
    f.write(header + beats + footer)
'
OUT_B2_4=$("$OODA_BIN" check "$TMP_B2_4" 2>&1)
RC_B2_4=$?
rm -f "$TMP_B2_4"
assert_exit_code 0 $RC_B2_4 \
  "B2.4 16 numbered beats boundary compiles cleanly"

# Test B2.5: Special characters in Title
TMP_B2_5="$TESTS_DIR/fixtures/tmp_bound_spec_title_$$.oo"
cat << 'EOF' > "$TMP_B2_5"
// # Title: Test & Validation (v1.0) @ [2026] <Sovereign> / Core
// Logline: Valid title with ASCII symbols.
// Setup: Pure compute.
// Beats:
//   1. Run fn.
pub fn spec_title_fn() -> Int { return 5; }
EOF
OUT_B2_5=$("$OODA_BIN" check "$TMP_B2_5" 2>&1)
RC_B2_5=$?
rm -f "$TMP_B2_5"
assert_exit_code 0 $RC_B2_5 \
  "B2.5 Special ASCII punctuation in Title compiles cleanly"
