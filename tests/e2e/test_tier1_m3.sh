#!/usr/bin/env bash
# Tier 1 M3: Features 10-13 (Symbols, Facts/Attributes, NSW, Assumes)
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OODAC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_m3_XXXXXX)"
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
  timeout 10s "$OODAC" check "$src" >/dev/null 2>&1
  timeout 10s "$OODAC" emit-llvm "$src" > "$out" 2>&1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 1 M3 (Features 10-13) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 10: Exact Runtime Symbol Table
  local f10_need_tab=0
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_need_tab.oo" ]]; then
    local l1
    l1=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_need_tab.oo")
    if [[ "$l1" -gt 256 ]]; then f10_need_tab=1; fi
  fi
  record_test "T1-F10-01" "ll_need_tab.oo satisfies wc -l <= 256" "$f10_need_tab"

  local f10_need_mod=0
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_need.oo" ]]; then
    local l2
    l2=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_need.oo")
    if [[ "$l2" -gt 256 ]]; then f10_need_mod=1; fi
  else
    f10_need_mod=1
  fi
  record_test "T1-F10-02" "ll_need.oo satisfies wc -l <= 256" "$f10_need_mod"

  cat << 'EOF' > "$d/pure_arith.oo"
// # Pure Arithmetic
// Logline: Test symbol table pruning
// Setup: emit-llvm
// Beats: math, main
pub fn add_nums(a: Int, b: Int) -> Int { return a + b; }
pub fn main() -> Int { return add_nums(10, 20); }
EOF
  local f10_prune=1
  if emit "$d/pure_arith.oo" "$d/pure_arith.ll"; then
    if ! grep -q "@oo_tui" "$d/pure_arith.ll" 2>/dev/null; then
      f10_prune=0
    fi
  fi
  record_test "T1-F10-03" "Pure arithmetic has no unneeded TUI symbols" "$f10_prune"

  local f10_fs=1
  if [[ -f "$d/pure_arith.ll" ]]; then
    if ! grep -q "@oo_fs_read" "$d/pure_arith.ll" 2>/dev/null; then
      f10_fs=0
    fi
  fi
  record_test "T1-F10-04" "Pure arithmetic has no unneeded FS symbols" "$f10_fs"

  local f10_as=1
  if [[ -f "$d/pure_arith.ll" ]]; then
    if llvm-as "$d/pure_arith.ll" -o "$d/pure.bc" >/dev/null 2>&1; then
      f10_as=0
    fi
  fi
  record_test "T1-F10-05" "Emitted symbol table passes llvm-as" "$f10_as"

  # Feature 11: Type Checker Facts & Attributes
  local f11_noundef=1
  if grep -q "noundef" "$d/pure_arith.ll" 2>/dev/null; then
    f11_noundef=0
  fi
  record_test "T1-F11-01" "noundef parameter attribute attached" "$f11_noundef"

  local f11_nocapture=1
  if grep -q "nocapture" "$d/pure_arith.ll" 2>/dev/null; then
    f11_nocapture=0
  fi
  record_test "T1-F11-02" "nocapture parameter attribute attached" "$f11_nocapture"

  local f11_nounwind=1
  if grep -q "nounwind" "$d/pure_arith.ll" 2>/dev/null; then
    f11_nounwind=0
  fi
  record_test "T1-F11-03" "nounwind function attribute attached" "$f11_nounwind"

  local f11_as=1
  if [[ -f "$d/pure_arith.ll" ]]; then
    if llvm-as "$d/pure_arith.ll" -o "$d/attrs.bc" >/dev/null 2>&1; then
      f11_as=0
    fi
  fi
  record_test "T1-F11-04" "LLVM attributes pass llvm-as validation" "$f11_as"

  local f11_ty_mod=0
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_ty.oo" ]]; then
    local l3
    l3=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_ty.oo")
    if [[ "$l3" -gt 256 ]]; then f11_ty_mod=1; fi
  else
    f11_ty_mod=1
  fi
  record_test "T1-F11-05" "ll_ty.oo satisfies wc -l <= 256" "$f11_ty_mod"

  # Feature 12: Signed NSW Arithmetic
  cat << 'EOF' > "$d/nsw_math.oo"
// # NSW Math Test
// Logline: Test signed arithmetic operations
// Setup: emit-llvm
// Beats: add, sub, mul, main
pub fn math_ops(a: Int, b: Int) -> Int {
  let s = a + b;
  let d = a - b;
  let p = a * b;
  return s + d + p;
}
pub fn main() -> Int { return math_ops(3, 4); }
EOF
  local f12_emit=1
  if emit "$d/nsw_math.oo" "$d/nsw_math.ll"; then f12_emit=0; fi
  record_test "T1-F12-01" "Signed arithmetic lowers cleanly" "$f12_emit"

  local f12_add=1
  if grep -q -E 'add (nsw )?i64' "$d/nsw_math.ll" 2>/dev/null; then
    f12_add=0
  fi
  record_test "T1-F12-02" "Emits signed integer addition" "$f12_add"

  local f12_sub=1
  if grep -q -E 'sub (nsw )?i64' "$d/nsw_math.ll" 2>/dev/null; then
    f12_sub=0
  fi
  record_test "T1-F12-03" "Emits signed integer subtraction" "$f12_sub"

  local f12_mul=1
  if grep -q -E 'mul (nsw )?i64' "$d/nsw_math.ll" 2>/dev/null; then
    f12_mul=0
  fi
  record_test "T1-F12-04" "Emits signed integer multiplication" "$f12_mul"

  local f12_as=1
  if [[ -f "$d/nsw_math.ll" ]]; then
    if llvm-as "$d/nsw_math.ll" -o "$d/nsw.bc" >/dev/null 2>&1; then
      f12_as=0
    fi
  fi
  record_test "T1-F12-05" "NSW arithmetic passes llvm-as" "$f12_as"

  # Feature 13: SMT Contract Assumes & Range
  local f13_decl=1
  if grep -q "@llvm.assume" "$d/pure_arith.ll" 2>/dev/null; then
    f13_decl=0
  fi
  record_test "T1-F13-01" "Declares @llvm.assume intrinsic" "$f13_decl"

  local f13_contract_mod=0
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_contract.oo" ]]; then
    local l4
    l4=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_contract.oo")
    if [[ "$l4" -gt 256 ]]; then f13_contract_mod=1; fi
  else
    f13_contract_mod=1
  fi
  record_test "T1-F13-02" "ll_contract.oo <= 256 LOC" "$f13_contract_mod"

  cat << 'EOF' > "$d/contract_spec.oo"
// # Contract Spec Test
// Logline: Contract verification
// Setup: emit-llvm
// Beats: ensures, main
pub fn fancy(x: Int) -> Int
  ensures result == x + 1
{
  return x + 1;
}
pub fn main() -> Int { return fancy(1); }
EOF
  local f13_chk=1
  if timeout 5s "$OODAC" check "$d/contract_spec.oo" >/dev/null 2>&1; then
    f13_chk=0
  fi
  record_test "T1-F13-03" "Contract specification parses and checks" "$f13_chk"

  local f13_emit=1
  if emit "$d/contract_spec.oo" "$d/contract_spec.ll"; then
    if llvm-as "$d/contract_spec.ll" -o "$d/spec.bc" >/dev/null 2>&1; then
      f13_emit=0
    fi
  fi
  record_test "T1-F13-04" "Contract lowered IR passes llvm-as" "$f13_emit"

  local f13_verify_mod=0
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_verify.oo" ]]; then
    local l5
    l5=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_verify.oo")
    if [[ "$l5" -gt 256 ]]; then f13_verify_mod=1; fi
  else
    f13_verify_mod=1
  fi
  record_test "T1-F13-05" "ll_verify.oo <= 256 LOC" "$f13_verify_mod"
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
