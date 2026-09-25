#!/usr/bin/env bash
# Tier 1: Result[Float, String] lowers end to end (Ok/Err/match/is_ok/unwrap).
# Float payloads are verified via == to Bool (float to_string is unimplemented).
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_resfloat_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OODA_FS_READDIR="${OODA_FS_READDIR:-$(cd "$PROJECT_ROOT/.." && pwd -P)}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_COMPILER="${OODA_COMPILER:-$OODAC}"

PASS_COUNT=0
FAIL_COUNT=0

record_test() {
  local id="$1" desc="$2" status="$3"
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
  echo "--- Executing resfloat suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  cat > "$d/basic.oo" << 'EOF'
// # resfloat basic
// Logline: x
// Setup: x
// Beats:
//   1. x
fn half(x: Float) -> Result[Float, String] {
    if x > 0.0 { return Ok(x); }
    return Err("non-positive");
}
pub fn main() {
    let a: Result[Float, String] = half(1.5);
    let b: Result[Float, String] = half(0.0);
    let va: Float = match a { Ok(v) => v, Err(_) => 0.0 };
    let eb: String = match b { Ok(_) => "unexpected", Err(e) => e };
    let cva: Bool = va == 1.5;
    println("va=" + cva.to_string() + " eb=" + eb + " oka=" + a.is_ok().to_string() + " okb=" + b.is_ok().to_string());
    let u: Float = half(2.5).unwrap();
    let cu: Bool = u == 2.5;
    println("u=" + cu.to_string());
    let w: Float = half(0.0).unwrap_or(3.25);
    let cw: Bool = w == 3.25;
    println("w=" + cw.to_string());
}
EOF

  local rb=1
  if timeout 120s "$OODAC" build --backend llvm "$d/basic.oo" -o "$d/basic.bin" >/dev/null 2>&1; then
    if [[ "$("$d/basic.bin" 2>/dev/null)" == "$(printf 'va=1 eb=non-positive oka=1 okb=0\nu=1\nw=1')" ]]; then
      rb=0
    fi
  fi
  record_test "RESFLOAT-01" "Ok/Err/match/is_ok/unwrap/unwrap_or round-trip" "$rb"

  local rw=1
  if timeout 120s "$OODAC" build --backend wasm "$d/basic.oo" -o "$d/basic.wasm" >/dev/null 2>&1; then
    rw=1
  else
    if [[ "$?" -eq 2 ]]; then rw=0; fi
  fi
  record_test "RESFLOAT-02" "wasm refuses Result[Float] with exit 2" "$rw"

  local rc=1
  if timeout 120s "$OODAC" build --backend rocm "$d/basic.oo" -o "$d/basic.rocm" >/dev/null 2>&1; then
    rc=1
  else
    if [[ "$?" -eq 2 ]]; then rc=0; fi
  fi
  record_test "RESFLOAT-03" "rocm refuses Result[Float] with exit 2" "$rc"
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
echo "INFO: resfloat suite completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
