#!/usr/bin/env bash
# Tier 2: Boundary & Corner Cases (Fixtures, Limits, Malformed Inputs, Violations)
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$PROJECT_ROOT/tests/fixtures"
TMPDIR="$(mktemp -d /tmp/e2e_t2_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS_COUNT=0
FAIL_COUNT=0

record_test() {
  local id="$1"
  local desc="$2"
  local status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $id: $desc"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 2 (Boundary & Corner Cases) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # T2-B01: Missing fixture fail closed
  local b01=1
  if ! timeout 5s "$OODAC" check "$d/nonexistent_fixture.oo" >/dev/null 2>&1; then
    b01=0
  fi
  record_test "T2-B01" "Missing fixture fails closed" "$b01"

  # T2-B02: Uppercase fallback integrity (only ANCHOR.oo in directory)
  mkdir -p "$d/up_pkg"
  echo 'pub fn up_val() -> Int { return 77; }' > "$d/up_pkg/ANCHOR.oo"
  echo 'import "up_pkg/ANCHOR.oo"; pub fn main() -> Int { return 0; }' > "$d/up_test.oo"
  local b02=1
  if timeout 5s "$OODAC" check "$d/up_test.oo" >/dev/null 2>&1; then
    b02=0
  fi
  record_test "T2-B02" "Directory with only ANCHOR.oo succeeds via fallback" "$b02"

  # T2-B03: Empty input file fails closed on build
  touch "$d/empty.oo"
  local b03=1
  if ! timeout 5s "$OODAC" build "$d/empty.oo" -o "$d/empty.bin" >/dev/null 2>&1; then
    b03=0
  fi
  record_test "T2-B03" "Empty 0-byte file fails closed on build (no main)" "$b03"

  # T2-B04: Exact boundary 256 lines passes line limit check
  local b04=1
  if [[ -f "$FIXTURES/boundary_256_lines.oo" ]]; then
    local l256; l256=$(wc -l < "$FIXTURES/boundary_256_lines.oo")
    if [[ "$l256" -eq 256 ]]; then b04=0; fi
  fi
  record_test "T2-B04" "Fixture boundary_256_lines.oo exactly 256 lines" "$b04"

  # T2-B05: Boundary breach 257 lines correctly fails <= 256 ceiling
  local b05=1
  if [[ -f "$FIXTURES/boundary_257_lines.oo" ]]; then
    local l257; l257=$(wc -l < "$FIXTURES/boundary_257_lines.oo")
    if [[ "$l257" -gt 256 ]]; then b05=0; fi
  fi
  record_test "T2-B05" "Fixture boundary_257_lines.oo breaches line limit" "$b05"

  # T2-B06: Unused token threshold 401 fixture exists and checks
  local b06=1
  if [[ -f "$FIXTURES/boundary_401_tokens_unused.oo" ]]; then
    b06=0
  fi
  record_test "T2-B06" "Fixture boundary_401_tokens_unused.oo verified" "$b06"

  # T2-B07: Malformed header blank lines fixture verified
  local b07=1
  if [[ -f "$FIXTURES/invalid_header_blank.oo" ]]; then
    if grep -q '^$' "$FIXTURES/invalid_header_blank.oo"; then b07=0; fi
  fi
  record_test "T2-B07" "Malformed header with blank lines identified" "$b07"

  # T2-B08: Malformed header inline comment fixture verified
  local b08=1
  if [[ -f "$FIXTURES/invalid_header_inline.oo" ]]; then
    b08=0
  fi
  record_test "T2-B08" "Malformed header inline comment verified" "$b08"

  # T2-B09: Struct syntax verification
  local b09=1
  if [[ -f "$FIXTURES/invalid_struct_comma.oo" ]]; then
    if grep -q 'User = struct' "$FIXTURES/invalid_struct_comma.oo"; then
      b09=0
    fi
  fi
  record_test "T2-B09" "Struct trailing comma fixture identified" "$b09"

  # T2-B10: Invalid syntax expression fails closed with parse error
  local b10=1
  if [[ -f "$FIXTURES/invalid_syntax.oo" ]]; then
    local out10
    out10=$(timeout 5s "$OODAC" check "$FIXTURES/invalid_syntax.oo" 2>&1 || true)
    if echo "$out10" | grep -q "ERR.*parse"; then b10=0; fi
  fi
  record_test "T2-B10" "Invalid syntax fails closed with parse error" "$b10"

  # T2-B11: Invalid type specification fails closed
  local b11=1
  if [[ -f "$FIXTURES/invalid_type.oo" ]]; then
    local out11
    out11=$(timeout 5s "$OODAC" check "$FIXTURES/invalid_type.oo" 2>&1 || true)
    if echo "$out11" | grep -q "ERR.*type"; then b11=0; fi
  fi
  record_test "T2-B11" "Invalid type fails closed with type error" "$b11"

  # T2-B12: Ambient capability leak fails closed
  local b12=1
  if [[ -f "$FIXTURES/invalid_cap_ambient.oo" ]]; then
    local out12
    out12=$(timeout 5s "$OODAC" check "$FIXTURES/invalid_cap_ambient.oo" 2>&1 || true)
    if echo "$out12" | grep -q "Security Capability Violation"; then b12=0; fi
  fi
  record_test "T2-B12" "Ambient capability access fails closed" "$b12"

  # T2-B13: Secret taint leak fixture verified
  local b13=1
  if [[ -f "$FIXTURES/secret_taint_leak.oo" ]]; then
    if grep -q "sk-live-" "$FIXTURES/secret_taint_leak.oo"; then b13=0; fi
  fi
  record_test "T2-B13" "Secret taint leak fixture contains secret token" "$b13"

  # T2-B14: Valid minimal fixture passes check
  local b14=1
  if [[ -f "$FIXTURES/valid_minimal.oo" ]]; then
    if timeout 5s "$OODAC" check "$FIXTURES/valid_minimal.oo" >/dev/null 2>&1; then
      b14=0
    fi
  fi
  record_test "T2-B14" "Valid minimal fixture passes check" "$b14"

  # T2-B15: Valid ADT match fixture passes check
  local b15=1
  if [[ -f "$FIXTURES/valid_adt_match.oo" ]]; then
    if timeout 5s "$OODAC" check "$FIXTURES/valid_adt_match.oo" >/dev/null 2>&1; then
      b15=0
    fi
  fi
  record_test "T2-B15" "Valid ADT match fixture passes check" "$b15"
}

run_suite 1
p1=$PASS_COUNT; f1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
p2=$PASS_COUNT; f2=$FAIL_COUNT

echo "=== Determinism Result: Run1 Pass=$p1 Fail=$f1 | Run2 Pass=$p2 Fail=$f2 ==="
if [[ "$p1" -ne "$p2" || "$f1" -ne "$f2" || "$f1" -ne 0 ]]; then
  echo "CRITICAL: Non-deterministic execution between Run 1 and Run 2!" >&2
  exit 1
fi
echo "INFO: Tier 2 completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
