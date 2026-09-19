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
// Logline: Option[&T] niche lowering
// Setup: emit-llvm
// Beats: opt, main
pub fn get_opt(flag: Bool, x: &Int) -> Option[&Int] {
  if flag { return Some(x); }
  return None;
}
pub fn main() -> Int {
  let a: Int = 42;
  let o = get_opt(true, &a);
  match o {
    Some(p) => { return *p; }
    None => { return 0; }
  }
}
EOF
  local f17_emit=1
  if emit "$d/opt_niche.oo" "$d/opt_niche.ll"; then f17_emit=0; fi
  record_test "T1-F17-01" "Option[&T] type parses and lowers to LLVM IR" "$f17_emit"

  local f17_none=1
  if [[ "$f17_emit" -eq 0 ]]; then
    if grep -q "ret ptr null" "$d/opt_niche.ll" 2>/dev/null; then
      f17_none=0
    fi
  fi
  record_test "T1-F17-02" "None constructor lowers directly to ptr null" "$f17_none"

  local f17_some=1
  if [[ "$f17_emit" -eq 0 ]]; then
    if grep -q "ret ptr %" "$d/opt_niche.ll" 2>/dev/null; then
      f17_some=0
    fi
  fi
  record_test "T1-F17-03" "Some(&x) returns pointer directly without wrapper" "$f17_some"

  local f17_match=1
  if [[ "$f17_emit" -eq 0 ]]; then
    if grep -qE "(icmp ne ptr .*null|icmp eq ptr .*null)" "$d/opt_niche.ll" 2>/dev/null; then
      f17_match=0
    fi
  fi
  record_test "T1-F17-04" "Match discriminant compiles to icmp ptr against null" "$f17_match"

  local f17_no_alloca=1
  if [[ "$f17_emit" -eq 0 ]]; then
    if ! grep -q "alloca %OoOpt" "$d/opt_niche.ll" 2>/dev/null; then
      f17_no_alloca=0
    fi
  fi
  record_test "T1-F17-05" "Intra-function Option[&T] contains zero alloca" "$f17_no_alloca"

  cat << 'EOF' > "$d/opt_mut.oo"
// # Option Mut Niche
// Logline: Option[&mut T] niche lowering
// Setup: emit-llvm
// Beats: mut_opt, main
pub fn get_mut(flag: Bool, x: &mut Int) -> Option[&mut Int] {
  if flag { return Some(x); }
  return None;
}
pub fn main() -> Int {
  let mut a: Int = 10;
  let o = get_mut(true, &mut a);
  match o {
    Some(p) => { *p = 20; return *p; }
    None => { return 0; }
  }
}
EOF
  local f17_mut=1
  if emit "$d/opt_mut.oo" "$d/opt_mut.ll"; then
    if llvm-as "$d/opt_mut.ll" -o "$d/om.bc" >/dev/null 2>&1; then
      f17_mut=0
    fi
  fi
  record_test "T1-F17-06" "Option[&mut T] lowers cleanly and passes llvm-as" "$f17_mut"

  # Feature 18: C ABI Marshalling
  local f18_rt=1
  if [[ "$f17_emit" -eq 0 ]]; then
    if grep -q "%OoOpt_Ptr = type { i32, ptr }" "$d/opt_niche.ll" 2>/dev/null && \
       grep -q "%OoRes_Ptr = type { i32, ptr }" "$d/opt_niche.ll" 2>/dev/null; then
      f18_rt=0
    fi
  fi
  record_test "T1-F18-01" "C ABI registers %OoOpt_Ptr and %OoRes_Ptr in runtime" "$f18_rt"

  local f18_c_abi=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_c_abi.oo" ]]; then
    if grep -q "ll_c_abi_pack_ret" "$OODAC_ROOT/emit/llvm/ll_c_abi.oo" && \
       grep -q "ll_c_abi_unpack_ret" "$OODAC_ROOT/emit/llvm/ll_c_abi.oo"; then
      f18_c_abi=0
    fi
  fi
  record_test "T1-F18-02" "C ABI marshaller provides pack/unpack routines" "$f18_c_abi"

  local f18_mod_len=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_c_abi.oo" ]]; then
    local lc; lc=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_c_abi.oo")
    if [[ "$lc" -le 256 ]]; then f18_mod_len=0; fi
  fi
  record_test "T1-F18-03" "ll_c_abi.oo satisfies wc -l <= 256" "$f18_mod_len"

  local f18_niche_len=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_niche.oo" ]]; then
    local ln; ln=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_niche.oo")
    if [[ "$ln" -le 256 ]]; then f18_niche_len=0; fi
  fi
  record_test "T1-F18-04" "ll_niche.oo satisfies wc -l <= 256" "$f18_niche_len"

  local f18_cap_len=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_cap.oo" ]]; then
    local lp; lp=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_cap.oo")
    if [[ "$lp" -le 256 ]]; then f18_cap_len=0; fi
  fi
  record_test "T1-F18-05" "ll_cap.oo satisfies wc -l <= 256" "$f18_cap_len"

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
    if grep -q "i64 noundef" "$d/cap_scalar.ll" 2>/dev/null; then
      f19_i64=0
    fi
  fi
  record_test "T1-F19-02" "Capability parameter strictly scalar i64 noundef" "$f19_i64"

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
