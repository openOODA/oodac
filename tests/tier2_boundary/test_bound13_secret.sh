#!/usr/bin/env bash
# # test_bound13_secret.sh — Tier 2 Boundary: Secret Taint Analysis
#
# Logline: Boundary tests for secret taint tracking: empty secrets, long keys,
#          sealed sinks, nested structs, and declassification contracts.
#
# Beats:
#   1. Test empty secret string literal.
#   2. Test 128-character secret key string.
#   3. Test passing secret to sealed hashing function.
#   4. Test nested struct containing secret field.
#   5. Test declassification pattern with formal contract.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B13 - Secret Taint Boundary"

# Test B13.1: Empty secret string
TMP_B13_1="$TESTS_DIR/fixtures/tmp_bound_sec_empty_$$.oo"
cat << 'EOF' > "$TMP_B13_1"
// # Empty Secret
// Logline: Empty string secret value.
// Setup: Pure compute.
// Beats: 1. Bind empty secret.
pub fn empty_sec() -> Int {
    let _s: String = "";
    return 0;
}
EOF
OUT_B13_1=$("$OODA_BIN" check "$TMP_B13_1" 2>&1)
RC_B13_1=$?
rm -f "$TMP_B13_1"
assert_exit_code 0 $RC_B13_1 \
  "B13.1 Empty string secret compiles cleanly"

# Test B13.2: 128-char secret string
LONG_KEY=$(python3 -c 'print("k" * 128)')
TMP_B13_2="$TESTS_DIR/fixtures/tmp_bound_sec_long_$$.oo"
cat << EOF > "$TMP_B13_2"
// # Long Secret
// Logline: 128 character secret key.
// Setup: Pure compute.
// Beats: 1. Bind key.
pub fn long_sec() -> Int {
    let _key: String = "$LONG_KEY";
    return 0;
}
EOF
OUT_B13_2=$("$OODA_BIN" check "$TMP_B13_2" 2>&1)
RC_B13_2=$?
rm -f "$TMP_B13_2"
assert_exit_code 0 $RC_B13_2 \
  "B13.2 128-character secret key literal compiles cleanly"

# Test B13.3: Passing secret to sealed mathematical transform
TMP_B13_3="$TESTS_DIR/fixtures/tmp_bound_sec_hash_$$.oo"
cat << 'EOF' > "$TMP_B13_3"
// # Sealed Hash
// Logline: Pure hash function transforms secret into digest.
// Setup: Pure compute.
// Beats: 1. Hash secret.
fn pure_hash(s: String) -> Int {
    let n = chars_len(s);
    return n * 31;
}
pub fn digest_sec() -> Int {
    let sec: String = "super_secret_payload";
    return pure_hash(sec);
}
EOF
OUT_B13_3=$("$OODA_BIN" check "$TMP_B13_3" 2>&1)
RC_B13_3=$?
rm -f "$TMP_B13_3"
assert_exit_code 0 $RC_B13_3 \
  "B13.3 Secret transformed through sealed pure function compiles cleanly"

# Test B13.4: Nested struct with secret field
TMP_B13_4="$TESTS_DIR/fixtures/tmp_bound_nest_struct_$$.oo"
cat << 'EOF' > "$TMP_B13_4"
// # Nested Struct Secret
// Logline: Multi-level struct containing secret field.
// Setup: Pure compute.
// Beats: 1. Extract non-secret field.
pub type Inner = struct {
    secret_val: String
};
pub type Outer = struct {
    id: Int,
    inner: Inner
};
pub fn extract_id(o: Outer) -> Int {
    return o.id;
}
EOF
OUT_B13_4=$("$OODA_BIN" check "$TMP_B13_4" 2>&1)
RC_B13_4=$?
rm -f "$TMP_B13_4"
assert_exit_code 0 $RC_B13_4 \
  "B13.4 Nested struct containing secret field compiles cleanly"

# Test B13.5: Declassification contract function
TMP_B13_5="$TESTS_DIR/fixtures/tmp_bound_declass_$$.oo"
cat << 'EOF' > "$TMP_B13_5"
// # Declassify Contract
// Logline: Formal declassification clause.
// Setup: Pure compute.
// Beats: 1. Redact string.
pub fn redact(s: String) -> String
spec "Redacts secret value to constant mask"
{
    return "[REDACTED]";
}
EOF
OUT_B13_5=$("$OODA_BIN" check "$TMP_B13_5" 2>&1)
RC_B13_5=$?
rm -f "$TMP_B13_5"
assert_exit_code 0 $RC_B13_5 \
  "B13.5 Declassification contract function compiles cleanly"
