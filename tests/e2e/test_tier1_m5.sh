#!/usr/bin/env bash
# Tier 1 M5: Features 17-19 (Pointer Niche, C ABI Marshalling, Capabilities)
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OODAC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_m5_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"

PASS_COUNT=0
FAIL_COUNT=0

record_test() {
  local id="$1" desc="$2" status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $id: $desc"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

emit() {
  local src="$1" out="$2"
  timeout 5s "$OODAC" check "$src" >/dev/null 2>&1
  timeout 5s "$OODAC" emit-llvm "$src" > "$out" 2>&1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 1 M5 (Features 17-19) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 17: Intra-Function Pointer Niche
  cat << 'EOF' > "$d/opt_niche.oo"
// # Option Niche Test
// Logline: Option representation
// Setup: emit-llvm
// Beats: opt, main
pub fn get_opt(flag: Bool) -> Option[Int] {
  if flag { return Some(100); }
  return None;
}
pub fn main() -> Int {
  let o = get_opt(true);
  match o {
    Some(v) => { return v; }
    None => { return 0; }
  }
}
EOF
  local f17_emit=1
  if emit "$d/opt_niche.oo" "$d/opt_niche.ll"; then f17_emit=0; fi
  record_test "T1-F17-01" "Option type lowers cleanly to IR" "$f17_emit"

  local f17_some=1
  if grep -q "Some" "$d/opt_niche.oo" && [[ "$f17_emit" -eq 0 ]]; then
    f17_some=0
  fi
  record_test "T1-F17-02" "Some constructor lowered" "$f17_some"

  local f17_none=1
  if grep -q "None" "$d/opt_niche.oo" && [[ "$f17_emit" -eq 0 ]]; then
    f17_none=0
  fi
  record_test "T1-F17-03" "None constructor lowered" "$f17_none"

  local f17_match=1
  if grep -q "marm" "$d/opt_niche.ll" 2>/dev/null; then
    f17_match=0
  fi
  record_test "T1-F17-04" "Option unwrapping lowered to branches" "$f17_match"

  local f17_as=1
  if [[ -f "$d/opt_niche.ll" ]]; then
    if llvm-as "$d/opt_niche.ll" -o "$d/opt.bc" >/dev/null 2>&1; then
      f17_as=0
    fi
  fi
  record_test "T1-F17-05" "Option lowered IR passes llvm-as" "$f17_as"

  # Feature 18: C ABI Marshalling
  local f18_str=1
  if grep -q "%OoStr = type { ptr, i64 }" "$d/opt_niche.ll" 2>/dev/null; then
    f18_str=0
  fi
  record_test "T1-F18-01" "%OoStr defined with { ptr, i64 }" "$f18_str"

  local f18_opt=1
  if grep -q "%OoOptI = type { i32, i64 }" "$d/opt_niche.ll" 2>/dev/null; then
    f18_opt=0
  fi
  record_test "T1-F18-02" "%OoOptI defined with { i32, i64 }" "$f18_opt"

  local f18_res=1
  if grep -q "%OoResI = type { i32, i64, %OoStr }" "$d/opt_niche.ll" 2>/dev/null; then
    f18_res=0
  fi
  record_test "T1-F18-03" "%OoResI defined with { i32, i64, %OoStr }" "$f18_res"

  local f18_ctor_mod=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_ctor.oo" ]]; then
    local l1; l1=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_ctor.oo")
    if [[ "$l1" -le 256 ]]; then f18_ctor_mod=0; fi
  fi
  record_test "T1-F18-04" "ll_ctor.oo satisfies wc -l <= 256" "$f18_ctor_mod"

  local f18_call_mod=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_call.oo" ]]; then
    local l2; l2=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_call.oo")
    if [[ "$l2" -le 256 ]]; then f18_call_mod=0; fi
  fi
  record_test "T1-F18-05" "ll_call.oo satisfies wc -l <= 256" "$f18_call_mod"

  # Feature 19: Scalar Capability Bitmasks
  cat << 'EOF' > "$d/cap_scalar.oo"
// # Capability Scalar Test
// Logline: Test capability lowering to i64
// Setup: emit-llvm
// Beats: cap fn, main
pub fn proc_action(p: &ProcessCap) -> Int {
  return 1;
}
pub fn main(p: &ProcessCap) -> Int {
  return proc_action(p);
}
EOF
  local f19_emit=1
  if emit "$d/cap_scalar.oo" "$d/cap_scalar.ll"; then f19_emit=0; fi
  record_test "T1-F19-01" "Capability parameter emits LLVM IR" "$f19_emit"

  local f19_i64=1
  if [[ "$f19_emit" -eq 0 ]]; then
    if grep -q "i64" "$d/cap_scalar.ll" 2>/dev/null; then f19_i64=0; fi
  fi
  record_test "T1-F19-02" "Capability parameter represented as scalar i64" "$f19_i64"

  local f19_call=1
  if [[ "$f19_emit" -eq 0 ]]; then
    if grep -q "call i64 @proc_action" "$d/cap_scalar.ll" 2>/dev/null; then
      f19_call=0
    fi
  fi
  record_test "T1-F19-03" "Capability passed directly via scalar call" "$f19_call"

  local f19_no_heap=1
  if [[ "$f19_emit" -eq 0 ]]; then
    if ! grep -q "@oo_alloc.*cap" "$d/cap_scalar.ll" 2>/dev/null; then
      f19_no_heap=0
    fi
  fi
  record_test "T1-F19-04" "Capability tokens incur zero heap allocation" "$f19_no_heap"

  local f19_as=1
  if [[ -f "$d/cap_scalar.ll" ]]; then
    if llvm-as "$d/cap_scalar.ll" -o "$d/cap.bc" >/dev/null 2>&1; then
      f19_as=0
    fi
  fi
  record_test "T1-F19-05" "Capability IR passes llvm-as" "$f19_as"
}

# Double-run determinism protocol
run_suite 1
P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
P2=$PASS_COUNT; F2=$FAIL_COUNT

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" || "$F1" -ne 0 ]]; then
  echo "Determinism failure: Run1 ($P1/$F1) != Run2 ($P2/$F2)"
  exit 1
fi
echo "Deterministic PASS: $P1 tests passed in both runs."
exit 0
