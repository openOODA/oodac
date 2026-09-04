#!/usr/bin/env bash
# # comb01_entry_and_typecheck.sh — Tier 3: Entry Gates x Typecheck Assurance
#
# Logline: Pairwise combination testing entry gate interface contracts with
#          static typecheck assurance across module boundaries.
#
# Beats:
#   1. Verify lex/ANCHOR.oo compiles cleanly under ooda check.
#   2. Verify qa/ANCHOR.oo compiles cleanly under ooda check.
#   3. Verify emit/gpu/ANCHOR.oo compiles cleanly under ooda check.
#   4. Verify external consumer importing valid domain entry gate.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 01 - Entry Gates x Typecheck Assurance"

# Test C1.1: lex/ANCHOR.oo typecheck passes cleanly
OUT_C1_1=$("$OODA_BIN" check "$REPO_ROOT/lex/ANCHOR.oo" 2>&1)
RC_C1_1=$?
assert_exit_code 0 $RC_C1_1 \
  "C1.1 lex/ANCHOR.oo passes ooda check with 0 type errors"

# Test C1.2: qa/ANCHOR.oo typecheck passes cleanly
OUT_C1_2=$("$OODA_BIN" check "$REPO_ROOT/qa/ANCHOR.oo" 2>&1)
RC_C1_2=$?
assert_exit_code 0 $RC_C1_2 \
  "C1.2 qa/ANCHOR.oo passes ooda check with 0 type errors"

# Test C1.3: emit/gpu/ANCHOR.oo typecheck passes cleanly
OUT_C1_3=$("$OODA_BIN" check "$REPO_ROOT/emit/gpu/ANCHOR.oo" 2>&1)
RC_C1_3=$?
assert_exit_code 0 $RC_C1_3 \
  "C1.3 emit/gpu/ANCHOR.oo passes ooda check with 0 type errors"

# Test C1.4: Consumer module importing canonical entry gate
TMP_CONS="$TESTS_DIR/fixtures/tmp_entry_consumer_$$.oo"
cat << 'EOF' > "$TMP_CONS"
// # Entry Consumer
// Logline: Imports lex/ANCHOR.oo and calls scan API.
// Setup: Pure compute.
// Beats: 1. Call entry.
import "lex/ANCHOR.oo";
pub fn test_entry_scan(s: String) -> List[String] {
    return lex_scan_source(s);
}
EOF
OUT_C1_4=$("$OODA_BIN" check "$TMP_CONS" 2>&1)
RC_C1_4=$?
rm -f "$TMP_CONS"
assert_exit_code 0 $RC_C1_4 \
  "C1.4 Consumer importing lex/ANCHOR.oo resolves lex_scan_source cleanly"
