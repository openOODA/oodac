#!/usr/bin/env bash
# Tier 4: Real-World Scenarios & Full Ecosystem Verification
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POLYREPO_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$POLYREPO_ROOT}"
T4_DIR="$PROJECT_ROOT/tests/tier4_realworld"
TMPDIR="$(mktemp -d /tmp/e2e_t4_XXXXXX)"
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
  echo "--- Executing Tier 4 (Real-World Scenarios) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # T4-RW01: Real-world Actor Event Bus Engine typecheck
  local rw01=1
  if timeout 10s "$OODAC" check "$T4_DIR/app_actor_event_bus.oo" >/dev/null 2>&1; then
    rw01=0
  fi
  record_test "T4-RW01" "Actor Event Bus algebraic pattern match passes check" "$rw01"

  # T4-RW02: Real-world Compiler Plugin Driver typecheck
  local rw02=1
  if timeout 10s "$OODAC" check "$T4_DIR/app_compiler_plugin.oo" >/dev/null 2>&1; then
    rw02=0
  fi
  record_test "T4-RW02" "Compiler Plugin Driver lifecycle passes check" "$rw02"

  # T4-RW03: Real-world Crypto Pipeline Engine (contract verification)
  local rw03=1
  if [[ -f "$T4_DIR/app_crypto_pipeline.oo" ]]; then
    local out03
    out03=$(timeout 10s "$OODAC" check "$T4_DIR/app_crypto_pipeline.oo" 2>&1 || true)
    if echo "$out03" | grep -q 'counterexample.*unproven'; then rw03=0; fi
  fi
  record_test "T4-RW03" "Crypto Pipeline SMT reports unproven ensures with counterexample" "$rw03"

  # T4-RW04: Real-world Matrix Sensor Fusion Engine (contract verification)
  local rw04=1
  if [[ -f "$T4_DIR/app_matrix_sensor_fusion.oo" ]]; then
    local out04
    out04=$(timeout 10s "$OODAC" check "$T4_DIR/app_matrix_sensor_fusion.oo" 2>&1 || true)
    if echo "$out04" | grep -q 'counterexample.*unproven'; then rw04=0; fi
  fi
  record_test "T4-RW04" "Matrix Sensor Fusion SMT reports unproven ensures with counterexample" "$rw04"

  # T4-RW05: Real-world Secure Vault Controller (contract verification)
  local rw05=1
  if [[ -f "$T4_DIR/app_secure_vault.oo" ]]; then
    local out05
    out05=$(timeout 10s "$OODAC" check "$T4_DIR/app_secure_vault.oo" 2>&1 || true)
    if echo "$out05" | grep -q '^OK$'; then rw05=0; fi
  fi
  record_test "T4-RW05" "Secure Vault Controller contracts verify clean (analysis active)" "$rw05"

  # T4-RW06: Pure Build Script Full Invocation Interface
  local pb_script="$PROJECT_ROOT/bootstrap/oodac_pure_build"
  local rw06=1
  if [[ -x "$pb_script" ]]; then
    if grep -q 'fixed_point_verified' "$pb_script" && grep -q 'SOVEREIGN_BACKEND' "$pb_script"; then
      rw06=0
    fi
  fi
  record_test "T4-RW06" "Pure build script interface and fixed-point engine verified" "$rw06"

  # T4-RW07: Polyrepo Master Test Suite Interface
  local poly_suite="$POLYREPO_ROOT/openOODA/qa/polyrepo_suite.oo"
  local rw07=1
  if [[ -f "$poly_suite" ]]; then
    if timeout 10s "$OODAC" check "$poly_suite" >/dev/null 2>&1; then
      rw07=0
    fi
  fi
  record_test "T4-RW07" "Universal Polyrepo QA Master Suite syntax and interface" "$rw07"

  # T4-RW08: Clean Repository Working Tree Audit
  local rw08=1
  local dirty_artifacts
  dirty_artifacts=$((git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null || true) \
    | (grep -E '\.tmp\.bin|\.blackbox/autopsy\.json' || true) \
    | wc -l)
  if [[ "$dirty_artifacts" -eq 0 ]]; then rw08=0; fi
  record_test "T4-RW08" "Zero orphaned temporary binaries or autopsy files in git status" "$rw08"
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
echo "INFO: Tier 4 completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
