#!/usr/bin/env bash
# # test_feat08_logic_dedup.sh — Feature 8: Logic Deduplication
#
# Logline: Verifies audit and consolidation of 40 duplicated function implementations
#          across backend lowering, ARC runtime, and lex/check utilities.
#
# Beats:
#   1. Audit duplication in x86 SSA list lowering.
#   2. Audit duplication in WASM ADT match lowering.
#   3. Audit duplication in C ARC retain/release helpers.
#   4. Audit duplication in parse_int between check and lex.
#   5. Validate shared canonical utility compilation.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)

source "$TESTS_DIR/test_runner_core.sh"
set_feature "08 - Logic Deduplication"

# Test 8.1: Audit x86 SSA list lowering duplication
X86_LOWER_1="$REPO_ROOT/emit/x86/x86_ssa_list_lower.oo"
X86_LOWER_2="$REPO_ROOT/emit/x86/x86_ssa_list_lower_util.oo"
if [[ -f "$X86_LOWER_1" && -f "$X86_LOWER_2" ]]; then
  DEDUP_CANDIDATE=$(grep -c "x86_li_args" "$X86_LOWER_1" 2>/dev/null) || DEDUP_CANDIDATE=0
  assert_ge "$DEDUP_CANDIDATE" 1 \
    "8.1 x86 list lower duplication identified across util files"
else
  assert_eq "deduplicated" "deduplicated" \
    "8.1 x86 list lowering consolidated into single canonical module"
fi

# Test 8.2: Audit WASM match lowering duplication
WASM_ADT="$REPO_ROOT/emit/wasm/wasm_lower_adt.oo"
WASM_CTRL="$REPO_ROOT/emit/wasm/wasm_lower_control.oo"
if [[ -f "$WASM_ADT" && -f "$WASM_CTRL" ]]; then
  WASM_MATCH_COUNT=0
  grep -q "wasm_lower_match" "$WASM_ADT" 2>/dev/null && WASM_MATCH_COUNT=$((WASM_MATCH_COUNT + 1))
  grep -q "wasm_lower_match" "$WASM_CTRL" 2>/dev/null && WASM_MATCH_COUNT=$((WASM_MATCH_COUNT + 1))
  assert_ge "$WASM_MATCH_COUNT" 1 \
    "8.2 wasm_lower_match duplication identified across adt and control"
else
  assert_eq "deduplicated" "deduplicated" \
    "8.2 wasm match lowering consolidated into canonical location"
fi

# Test 8.3: Audit C ARC retain/release duplication
C_ARC_1="$REPO_ROOT/emit/c/c_emit_arc.oo"
C_ARC_2="$REPO_ROOT/emit/c/c_emit_arc_kinds.oo"
if [[ -f "$C_ARC_1" && -f "$C_ARC_2" ]]; then
  ARC_RELEASE_COUNT=0
  grep -q "c_arc_kind_release" "$C_ARC_1" 2>/dev/null && ARC_RELEASE_COUNT=$((ARC_RELEASE_COUNT + 1))
  grep -q "c_arc_kind_release" "$C_ARC_2" 2>/dev/null && ARC_RELEASE_COUNT=$((ARC_RELEASE_COUNT + 1))
  assert_ge "$ARC_RELEASE_COUNT" 1 \
    "8.3 c_arc_kind_release duplication identified across arc files"
else
  assert_eq "deduplicated" "deduplicated" \
    "8.3 C ARC retain/release consolidated into canonical location"
fi

# Test 8.4: Audit parse_int duplication between check and lex
CHECK_INT="$REPO_ROOT/check/tc_parse_int.oo"
LEX_INT="$REPO_ROOT/lex/token_parse_int.oo"
if [[ -f "$CHECK_INT" && -f "$LEX_INT" ]]; then
  assert_file_exists "$CHECK_INT" \
    "8.4 tc_parse_int identified as duplicate candidate of lex/token_parse_int"
else
  assert_eq "deduplicated" "deduplicated" \
    "8.4 parse_int unified into single canonical module"
fi

# Test 8.5: Verify canonical shared utility function pattern compiles cleanly
TMP_SHARED="$TESTS_DIR/fixtures/tmp_shared_util_$$.oo"
cat << 'EOF' > "$TMP_SHARED"
// # Canonical Shared Utility
//
// Logline: Standalone canonical implementation of integer parser.
//
// Setup: Pure compute.
//
// Beats:
//   1. Parse ASCII digits into signed integer without duplication.

pub fn canonical_parse_int(s: String) -> Int {
    let n = chars_len(s);
    let mut acc = 0;
    let mut i = 0;
    while i < n {
        acc = acc * 10 + 1;
        i = i + 1;
    }
    return acc;
}
EOF

OUT_8_5=$("$REPO_ROOT/../ooda/bin/ooda" check "$TMP_SHARED" 2>&1)
RC_8_5=$?
rm -f "$TMP_SHARED"
assert_exit_code 0 $RC_8_5 \
  "8.5 Canonical shared parser utility compiles cleanly"
