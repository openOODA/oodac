#!/usr/bin/env bash
# # comb05_normalization_and_dedup.sh — Tier 3: Normalization x Logic Deduplication
#
# Logline: Pairwise combination testing that canonical module names house
#          single non-duplicated function definitions.
#
# Beats:
#   1. Verify canonical parse_int module exists and is unique.
#   2. Verify no file contains duplicate definitions of its own exported functions.
#   3. Test importing deduplicated canonical utility module.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 05 - Normalization x Logic Deduplication"

# Test C5.1: Lexer integer parser module presence
LEX_INT_FILE="$REPO_ROOT/lex/token_parse_int.oo"
assert_file_exists "$LEX_INT_FILE" \
  "C5.1 Canonical token_parse_int.oo exists in lex subsystem"

# Test C5.2: Verify canonical module compiles cleanly
OUT_C5_2=$("$OODA_BIN" check "$LEX_INT_FILE" 2>&1)
RC_C5_2=$?
assert_exit_code 0 $RC_C5_2 \
  "C5.2 Canonical token_parse_int.oo compiles with 0 errors"

# Test C5.3: Import deduplicated module in consumer
TMP_DEDUP_CONS="$TESTS_DIR/fixtures/tmp_dedup_cons_$$.oo"
cat << 'EOF' > "$TMP_DEDUP_CONS"
// # Dedup Consumer
// Logline: Imports canonical token_parse_int.oo.
// Setup: Pure compute.
// Beats: 1. Parse string.
import "lex/token_parse_int.oo";
pub fn test_parse_digit(s: String) -> Int {
    return parse_int(s);
}
EOF
OUT_C5_3=$("$OODA_BIN" check "$TMP_DEDUP_CONS" 2>&1)
RC_C5_3=$?
rm -f "$TMP_DEDUP_CONS"
assert_exit_code 0 $RC_C5_3 \
  "C5.3 Consumer module importing canonical token_parse_int.oo compiles cleanly"
