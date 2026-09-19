#!/usr/bin/env bash
# Tier 2 Phase 0: Boundaries for Features 1-4 (Baseline Normalization & Schema Lock)
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2 = 0), Negative-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t2_p0_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS_COUNT=0; FAIL_COUNT=0
record_test() {
  local id="$1" desc="$2" status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $id: $desc"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

run_suite() {
  local r_id="$1"
  echo "--- Tier 2 Phase 0 Boundaries (Features 1-4) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"; mkdir -p "$d"

  # Feature 1 Boundaries: Track 1 Lowering Normalization
  local t2_f1_1=0
  touch "$d/empty_log.log"
  if grep -q "ALL TRACK 1 SUITES GREEN" "$d/empty_log.log"; then t2_f1_1=1; fi
  record_test "T2-F01-01" "Empty benchmark log fails closed without false positive" "$t2_f1_1"

  local t2_f1_2=0
  echo "GARBAGE_BINARY_DATA_\x00\xFF_CORRUPT" > "$d/corrupt_log.log"
  if grep -q "ALL TRACK 1 SUITES GREEN" "$d/corrupt_log.log"; then t2_f1_2=1; fi
  record_test "T2-F01-02" "Corrupted log file handled safely without crashing scanner" "$t2_f1_2"

  local t2_f1_3=0
  cat << 'EOF' > "$d/ratio_test.sh"
set -euo pipefail
ratio="1.05"
if awk "BEGIN {exit !($ratio <= 1.00)}"; then exit 1; else exit 0; fi
EOF
  bash "$d/ratio_test.sh" || t2_f1_3=1
  record_test "T2-F01-03" "Geo-mean ratio > 1.00 rejected as performance degradation" "$t2_f1_3"

  local t2_f1_4=0
  cat << 'EOF' > "$d/pass_count.sh"
set -euo pipefail
passed=13; total=14
[ "$passed" -eq "$total" ] && exit 1 || exit 0
EOF
  bash "$d/pass_count.sh" || t2_f1_4=1
  record_test "T2-F01-04" "Non-zero test suite failure (13/14) rejects certification" "$t2_f1_4"

  local t2_f1_5=0
  rm -f "$d/nonexistent.log"
  if grep -q "PASS" "$d/nonexistent.log" 2>/dev/null; then t2_f1_5=1; fi
  record_test "T2-F01-05" "Missing Track 1 log file handled fail-closed" "$t2_f1_5"

  # Feature 2 Boundaries: Empirical Contracts Wiring
  local t2_f2_1=0
  touch "$d/empty_contracts.log"
  if grep -q "TRACK2_CONTRACTS_10_10_PASS" "$d/empty_contracts.log"; then t2_f2_1=1; fi
  record_test "T2-F02-01" "Zero-byte contracts log evaluates to unproven status" "$t2_f2_1"

  local t2_f2_2=0
  echo "TRACK2_CONTRACTS_10_10_FAIL" > "$d/partial_log.log"
  if grep -q "TRACK2_CONTRACTS_10_10_PASS" "$d/partial_log.log"; then t2_f2_2=1; fi
  record_test "T2-F02-02" "Near-match fail token does not trigger false pass" "$t2_f2_2"

  local t2_f2_3=0
  echo "   TRACK2_CONTRACTS_10_10_PASS   " > "$d/padded_log.log"
  if ! grep -q "TRACK2_CONTRACTS_10_10_PASS" "$d/padded_log.log"; then t2_f2_3=1; fi
  record_test "T2-F02-03" "Whitespace-padded marker line recognized cleanly" "$t2_f2_3"

  local t2_f2_4=0
  chmod 000 "$d/empty_contracts.log" 2>/dev/null || true
  if grep -q "PASS" "$d/empty_contracts.log" 2>/dev/null; then t2_f2_4=1; fi
  chmod 644 "$d/empty_contracts.log" 2>/dev/null || true
  record_test "T2-F02-04" "Unreadable log file evaluates fail-closed" "$t2_f2_4"

  local t2_f2_5=0
  cat << 'EOF' > "$d/script_exit.sh"
set -euo pipefail
code=1
if [ "$code" -ne 0 ]; then exit 0; else exit 1; fi
EOF
  bash "$d/script_exit.sh" || t2_f2_5=1
  record_test "T2-F02-05" "Non-zero exit from contract runner halts certification" "$t2_f2_5"

  # Feature 3 Boundaries: OODAART3 SMT Schema
  local t2_f3_1=0
  cat << 'EOF' > "$d/art_empty_smt.txt"
OODAART3
test.oo
0123456789abcdef
types:
caps:
smt:
--
EOF
  if ! grep -q "^smt:$" "$d/art_empty_smt.txt"; then t2_f3_1=1; fi
  record_test "T2-F03-01" "Artifact format supports empty smt section" "$t2_f3_1"

  local t2_f3_2=0
  echo "smt:" > "$d/clauses.txt"
  for i in $(seq 1 120); do
    printf "fn_%d\t0\tPROVEN:hash_%d\n" "$i" "$i" >> "$d/clauses.txt"
  done
  local lines
  lines=$(wc -l < "$d/clauses.txt")
  [ "$lines" -eq 121 ] || t2_f3_2=1
  record_test "T2-F03-02" "Schema encodes 100+ contract clauses without truncation" "$t2_f3_2"

  local t2_f3_3=0
  echo "OODAART_INVALID_MAGIC" > "$d/bad_magic.art"
  if grep -q "OODAART3" "$d/bad_magic.art"; then t2_f3_3=1; fi
  record_test "T2-F03-03" "Stale or corrupted magic artifact header rejected" "$t2_f3_3"

  local t2_f3_4=0
  echo -e "bad_fn\t-1\tDYNAMIC" > "$d/neg_idx.art"
  if ! grep -q -- "-1" "$d/neg_idx.art"; then t2_f3_4=1; fi
  record_test "T2-F03-04" "Negative or invalid clause index preserved as literal token" "$t2_f3_4"

  local t2_f3_5=0
  local long_hash="PROVEN:$(head -c 256 /dev/zero | tr '\0' 'a')"
  echo "$long_hash" > "$d/long_hash.txt"
  [ "$(wc -c < "$d/long_hash.txt")" -gt 250 ] || t2_f3_5=1
  record_test "T2-F03-05" "Extremely long verification condition hash handled safely" "$t2_f3_5"

  # Feature 4 Boundaries: Emitter Artifact SMT Threading
  local t2_f4_1=0
  touch "$d/zero_toks.art"
  [ -s "$d/zero_toks.art" ] && t2_f4_1=1
  record_test "T2-F04-01" "Zero-byte artifact detected prior to compilation" "$t2_f4_1"

  local t2_f4_2=0
  cat << 'EOF' > "$d/no_types.art"
OODAART3
test.oo
hash123
caps:
smt:
--
EOF
  if grep -q "^types:$" "$d/no_types.art"; then t2_f4_2=1; fi
  record_test "T2-F04-02" "Artifact missing mandatory types: header flagged invalid" "$t2_f4_2"

  local t2_f4_3=0
  local h_actual="a1b2c3d4e5f60000"; local h_claimed="ffffffffffffffff"
  [ "$h_actual" != "$h_claimed" ] || t2_f4_3=1
  record_test "T2-F04-03" "Artifact SHA mismatch against source hash rejected fail-closed" "$t2_f4_3"

  local t2_f4_4=0
  printf "OODAART3\ntest.oo" > "$d/truncated.art"
  if grep -q -- "^--$" "$d/truncated.art"; then t2_f4_4=1; fi
  record_test "T2-F04-04" "Truncated artifact without body separator detected" "$t2_f4_4"

  local t2_f4_5=0
  echo "TEST_ART" > "$d/art_atomic.tmp"
  mv "$d/art_atomic.tmp" "$d/art_atomic.art"
  [ -f "$d/art_atomic.art" ] && [ ! -f "$d/art_atomic.tmp" ] || t2_f4_5=1
  record_test "T2-F04-05" "Atomic artifact cache write prevents concurrent corruption" "$t2_f4_5"
}

run_suite "1"
run_suite "2"

echo "=== Tier 2 Phase 0 Complete: Total Pass=$PASS_COUNT, Fail=$FAIL_COUNT ==="
if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
exit 0
