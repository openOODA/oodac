#!/usr/bin/env bash
# Tier 1: OODA_LLVM_CPU target plumbing (clang -march + IR attributes).
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
# Needs a rebuilt oodac (cli_cpu.oo + ll_cpu.oo); red on older binaries.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_cputarget_XXXXXX)"
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
  echo "--- Executing LLVM cpu-target suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  cat > "$d/targ.oo" << 'EOF'
fn add(a: Int, b: Int) -> Int {
    return a + b;
}
pub fn main() {
    println(add(40, 2));
}
EOF

  local chk=1
  if timeout 60s "$OODAC" check "$d/targ.oo" >/dev/null 2>&1; then
    chk=0
  fi
  record_test "CPU-00" "check passes on target fixture" "$chk"

  # 1. Unset var: no attributes group, no #0 on defines.
  local base_ok=1
  if [[ "$chk" -eq 0 ]] && env -u OODA_LLVM_CPU timeout 60s "$OODAC" emit-llvm "$d/targ.oo" > "$d/base.ll" 2>&1; then
    if ! grep -F -q "attributes #0" "$d/base.ll" 2>/dev/null && ! grep -E -q "^define .* #0" "$d/base.ll" 2>/dev/null; then
      base_ok=0
    fi
  fi
  record_test "CPU-01" "unset cpu leaves baseline IR untouched" "$base_ok"

  # 2. Set var: attributes group plus #0 on every user define.
  local attr_ok=1
  if [[ "$chk" -eq 0 ]] && OODA_LLVM_CPU=x86-64-v3 timeout 60s "$OODAC" emit-llvm "$d/targ.oo" > "$d/v3.ll" 2>&1; then
    if grep -F -q 'attributes #0 = { "target-cpu"="x86-64-v3" }' "$d/v3.ll" 2>/dev/null \
      && [[ "$(grep -E -c "^define .* #0" "$d/v3.ll" 2>/dev/null)" -ge 2 ]]; then
      attr_ok=0
    fi
  fi
  record_test "CPU-02" "set cpu stamps attributes and defines" "$attr_ok"

  # 3. Valid cpu builds; baseline cpu binary runs.
  local build_ok=1
  if [[ "$chk" -eq 0 ]] && OODA_LLVM_CPU=x86-64-v3 timeout 120s "$OODAC" build "$d/targ.oo" -o "$d/targ_v3" >/dev/null 2>&1; then
    build_ok=0
  fi
  record_test "CPU-03" "build succeeds with valid cpu" "$build_ok"

  local run_ok=1
  if [[ "$chk" -eq 0 ]] && OODA_LLVM_CPU=x86-64 timeout 120s "$OODAC" build "$d/targ.oo" -o "$d/targ_base" >/dev/null 2>&1; then
    if ( cd "$d" && ./targ_base > targ_base.out 2>&1 ) && grep -F -q "42" "$d/targ_base.out" 2>/dev/null; then
      run_ok=0
    fi
  fi
  record_test "CPU-04" "baseline cpu binary runs and prints" "$run_ok"

  # 4. Bad charset fails closed inside oodac.
  local bad_ok=1
  if OODA_LLVM_CPU='a;b' timeout 120s "$OODAC" build "$d/targ.oo" -o "$d/targ_bad" > "$d/bad.log" 2>&1; then
    bad_ok=1
  else
    if grep -F -q "bad cpu" "$d/bad.log" 2>/dev/null; then
      bad_ok=0
    fi
  fi
  record_test "CPU-05" "bad cpu name fails closed with message" "$bad_ok"

  # 5. Unknown-but-clean cpu reaches clang (delivery proof).
  local unk_ok=1
  if OODA_LLVM_CPU=zzz-no-such-cpu-9 timeout 120s "$OODAC" build "$d/targ.oo" -o "$d/targ_unk" > "$d/unk.log" 2>&1; then
    unk_ok=1
  else
    if grep -F -q "zzz-no-such-cpu-9" "$d/unk.log" 2>/dev/null; then
      unk_ok=0
    fi
  fi
  record_test "CPU-06" "unknown cpu surfaces clang error naming it" "$unk_ok"
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
echo "INFO: LLVM cpu-target suite completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
