#!/usr/bin/env bash
# # comb08_secret_taint_and_capabilities.sh — Tier 3: Secret Taint x Capability Security
#
# Logline: Pairwise combination testing dataflow taint tracking across
#          privileged capability boundaries and sealed sinks.
#
# Beats:
#   1. Verify secret variable handling in module with capabilities.
#   2. Verify pure hashing functions do not compromise secret taint model.
#   3. Verify encapsulated secret struct access under capability token.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-/home/jeryd/Projects/openOODA/ooda/bin/ooda}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Comb 08 - Secret Taint x Capabilities"

# Test C8.1: Secret variable in capability-mediated module compiles cleanly
TMP_C8_1="$TESTS_DIR/fixtures/tmp_sec_cap_mod_$$.oo"
cat << 'EOF' > "$TMP_C8_1"
// # Secret Cap Module
// Logline: Secret token held in memory under FsReadCap.
// Setup: Pure compute.
// Beats: 1. Hold secret.
pub fn secure_audit(fs: &FsReadCap) -> Int {
    let _token = "vault_master_key_999";
    return 1;
}
EOF
OUT_C8_1=$("$OODA_BIN" check "$TMP_C8_1" 2>&1)
RC_C8_1=$?
rm -f "$TMP_C8_1"
assert_exit_code 0 $RC_C8_1 \
  "C8.1 Module holding secret token under &FsReadCap compiles cleanly"

# Test C8.2: Secret dataflow through sealed cryptographic transform
TMP_C8_2="$TESTS_DIR/fixtures/tmp_sec_hash_cap_$$.oo"
cat << 'EOF' > "$TMP_C8_2"
// # Sealed Cryptographic Sink
// Logline: Secret passed to pure hash without leaking to unsealed sink.
// Setup: Pure compute.
// Beats: 1. Hash secret.
fn compute_digest(s: String) -> Int {
    return chars_len(s) * 17;
}
pub fn secure_hasher(fs: &FsReadCap, secret_input: String) -> Int {
    let digest: Int = compute_digest(secret_input);
    return digest;
}
EOF
OUT_C8_2=$("$OODA_BIN" check "$TMP_C8_2" 2>&1)
RC_C8_2=$?
rm -f "$TMP_C8_2"
assert_exit_code 0 $RC_C8_2 \
  "C8.2 Secret transformed through sealed pure function compiles cleanly"
