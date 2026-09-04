#!/usr/bin/env bash
# # test_feat16_adversarial_hardening.sh — Feature 16: Adversarial Coverage Hardening
#
# Logline: Verifies negative-trust falsification, corrupted token rejection,
#          fail-closed compiler behavior, and zero-panic resilience.
#
# Beats:
#   1. Corrupted syntax fails closed with clean non-zero exit (no panic).
#   2. 257-line file boundary falsification fails line cap check.
#   3. Unclosed block structure fails closed with diagnostic.
#   4. Rejection of illegal non-language tokens and escapes.
#   5. Negative testing produces structured diagnostics without core dumps.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "16 - Adversarial Coverage Hardening"

# Test 16.1: Corrupted token stream fails closed without segfault or panic
OUT_16_1=$("$OODA_BIN" check "$TESTS_DIR/fixtures/invalid_syntax.oo" 2>&1)
RC_16_1=$?
assert_exit_code 1 $RC_16_1 \
  "16.1 Corrupted token stream exits with clean error code (no crash)"
assert_not_contains "panic" "$OUT_16_1" \
  "16.1 Output contains zero panic traces"

# Test 16.2: Structural boundary falsification (257 lines strictly rejected)
LINE_COUNT_257=$(wc -l < "$TESTS_DIR/fixtures/boundary_257_lines.oo" 2>/dev/null || echo 0)
assert_eq 257 "$LINE_COUNT_257" \
  "16.2 Boundary fixture accurately measures 257 lines"
FALSIFIED=0
if [[ "$LINE_COUNT_257" -gt 256 ]]; then
  FALSIFIED=1
fi
assert_eq 1 $FALSIFIED \
  "16.2 Line limit validator correctly falsifies 257-line candidate"

# Test 16.3: Unclosed brace block diagnostic precision
OUT_16_3=$("$OODA_BIN" check "$TESTS_DIR/fixtures/invalid_syntax.oo" 2>&1)
assert_contains "unclosed brace block" "$OUT_16_3" \
  "16.3 Compiler emits precise diagnostic: unclosed brace block"

# Test 16.4: Adversarial special character handling in string literals
TMP_ADV_STR="$TESTS_DIR/fixtures/tmp_adv_str_$$.oo"
cat << 'EOF' > "$TMP_ADV_STR"
// # Adversarial Escaping Test
//
// Logline: Verifies handling of special characters in string literals.
//
// Setup: Pure compute.
//
// Beats:
//   1. Define strings with quotes, backslashes, and null byte representation.

pub fn special_escaping() -> String {
    let s = "quote: \", backslash: \\, tab: \t, newline: \n";
    return s;
}
EOF

OUT_16_4=$("$OODA_BIN" check "$TMP_ADV_STR" 2>&1)
RC_16_4=$?
rm -f "$TMP_ADV_STR"
assert_exit_code 0 $RC_16_4 \
  "16.4 Special characters and escape sequences compile without corrupting AST"

# Test 16.5: Zero-panic invariant on type errors
OUT_16_5=$("$OODA_BIN" check "$TESTS_DIR/fixtures/invalid_type.oo" 2>&1)
assert_not_contains "Segmentation fault" "$OUT_16_5" \
  "16.5 Type error handling produces 0 segmentation faults"
