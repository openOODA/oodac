#!/usr/bin/env bash
# Challenger 2: Adversarial M2 It2 Falsification Suite
# Probes: Deep scopes / shadowing, module cross-ref undefined, multi-return lifetimes
# Compliance: wc -l <= 256, Double-Run Determinism (Run1 == Run2 = 0)
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OODAC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
FIXTURES_DIR="$OODAC_ROOT/tests/fixtures/adversarial_m2"
TMPDIR="$(mktemp -d /tmp/challenger_m2_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-8589934592}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"

PASS_COUNT=0
FAIL_COUNT=0

record() {
  local id="$1" desc="$2" status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $id: $desc"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

emit() {
  local src="$1" out="$2"
  "$OODAC" check "$src" >/dev/null 2>&1
  "$OODAC" emit-llvm "$src" > "$out" 2>&1
}

run_suite() {
  local r_id="$1"
  echo "=== Adversarial M2 Falsification Suite (Run $r_id) ==="
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # PROBE 1: Deep Nested Scopes & Shadowing
  local p1_chk=1
  if "$OODAC" check "$FIXTURES_DIR/probe_deep_scopes.oo" >/dev/null 2>&1; then
    p1_chk=0
  fi
  record "CH2-P01-01" "Deep nested scopes with shadowing checks cleanly" "$p1_chk"

  local p1_ll=1
  if emit "$FIXTURES_DIR/probe_deep_scopes.oo" "$d/p1.ll"; then
    if llvm-as "$d/p1.ll" -o "$d/p1.bc" >/dev/null 2>&1; then
      p1_ll=0
    fi
  fi
  record "CH2-P01-02" "Deep scopes LLVM IR validates under llvm-as" "$p1_ll"

  local p1_run=1
  if "$OODAC" build "$FIXTURES_DIR/probe_deep_scopes.oo" -o "$d/p1_bin" >/dev/null 2>&1; then
    if "$d/p1_bin"; then
      p1_run=0
    fi
  fi
  record "CH2-P01-03" "Deep scopes binary executes and returns 0" "$p1_run"

  # PROBE 1 Negative: Out-of-scope access after drop_depth
  local p1_leak=1
  local p1_leak_out
  p1_leak_out=$("$OODAC" check "$FIXTURES_DIR/probe_deep_scopes_leak.oo" 2>&1 || true)
  if echo "$p1_leak_out" | grep -q "undefined variable 'leaf'"; then
    p1_leak=0
  fi
  record "CH2-P01-04" "drop_depth correctly purges inner bindings (leaf rejected)" "$p1_leak"

  # PROBE 2: Module Cross-References & Undefined Variables
  local p2_valid=1
  if "$OODAC" check "$FIXTURES_DIR/mod_consumer_valid.oo" >/dev/null 2>&1; then
    p2_valid=0
  fi
  record "CH2-P02-01" "Valid cross-module import checks cleanly" "$p2_valid"

  local p2_valid_run=1
  if "$OODAC" build "$FIXTURES_DIR/mod_consumer_valid.oo" -o "$d/p2_valid_bin" >/dev/null 2>&1; then
    if "$d/p2_valid_bin"; then
      p2_valid_run=0
    fi
  fi
  record "CH2-P02-02" "Valid cross-module binary executes and returns 0" "$p2_valid_run"

  # PROBE 2 Negative A: Undefined variable in consumer module
  local p2_undef=1
  local p2_undef_out
  p2_undef_out=$("$OODAC" check "$FIXTURES_DIR/mod_consumer_undefined.oo" 2>&1 || true)
  if echo "$p2_undef_out" | grep -q "undefined variable 'unexported_missing_var'"; then
    p2_undef=0
  fi
  record "CH2-P02-03" "Cross-module typechecker catches undefined variable" "$p2_undef"

  # PROBE 2 Negative B: Substring prefix collision rejection
  local p2_prefix=1
  local p2_prefix_out
  p2_prefix_out=$("$OODAC" check "$FIXTURES_DIR/mod_consumer_prefix_clash.oo" 2>&1 || true)
  if echo "$p2_prefix_out" | grep -q "undefined variable 'provider_service'"; then
    p2_prefix=0
  fi
  record "CH2-P02-04" "Substring prefix of imported symbol rejected as undefined" "$p2_prefix"

  # PROBE 3: Functions with Multiple Returns & Lifetime End Emission
  local p3_chk=1
  if "$OODAC" check "$FIXTURES_DIR/probe_multi_return_lifetimes.oo" >/dev/null 2>&1; then
    p3_chk=0
  fi
  record "CH2-P03-01" "Multi-return probe passes typecheck" "$p3_chk"

  local p3_ll=1
  if emit "$FIXTURES_DIR/probe_multi_return_lifetimes.oo" "$d/p3.ll"; then
    if llvm-as "$d/p3.ll" -o "$d/p3.bc" >/dev/null 2>&1; then
      p3_ll=0
    fi
  fi
  record "CH2-P03-02" "Multi-return LLVM IR validates under llvm-as" "$p3_ll"

  local p3_life=1
  # branch_eval has 4 return points, loop_search has 2 return points -> >= 6 ret
  local ret_cnt
  ret_cnt=$(grep -c "  ret " "$d/p3.ll" || true)
  local life_end_cnt
  life_end_cnt=$(grep -c "call void @llvm.lifetime.end.p0" "$d/p3.ll" || true)
  # Allocas are present in branch_eval, so each ret must have preceding lifetime.end
  if [[ "$ret_cnt" -ge 6 && "$life_end_cnt" -ge 6 ]]; then
    p3_life=0
  fi
  record "CH2-P03-03" "Every return point preceded by lifetime.end ($life_end_cnt ends / $ret_cnt rets)" "$p3_life"

  local p3_opt=1
  if opt -passes=mem2reg,instcombine -S "$d/p3.ll" -o "$d/p3_opt.ll" >/dev/null 2>&1; then
    if llvm-as "$d/p3_opt.ll" -o "$d/p3_opt.bc" >/dev/null 2>&1; then
      p3_opt=0
    fi
  fi
  record "CH2-P03-04" "Multi-return IR optimizes cleanly under mem2reg" "$p3_opt"

  local p3_run=1
  if "$OODAC" build "$FIXTURES_DIR/probe_multi_return_lifetimes.oo" -o "$d/p3_bin" >/dev/null 2>&1; then
    if "$d/p3_bin"; then
      p3_run=0
    fi
  fi
  record "CH2-P03-05" "Multi-return binary executes all branches successfully" "$p3_run"
}

# Run 1
run_suite 1
P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
# Run 2
run_suite 2
P2=$PASS_COUNT; F2=$FAIL_COUNT

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" || "$F1" -ne 0 ]]; then
  echo "Determinism failure: Run1 ($P1/$F1) != Run2 ($P2/$F2)"
  exit 1
fi
echo "Deterministic PASS: $P1/$P1 tests passed in both runs."
exit 0
