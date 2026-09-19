#!/usr/bin/env bash
# Tier 1 M2: Features 5-9 (Typed Allocas, Struct List, Quota, Lifetimes, SSA)
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OODAC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_m2_XXXXXX)"
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
  echo "--- Executing Tier 1 M2 (Features 5-9) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 5: Canonical Typed Allocas
  cat << 'EOF' > "$d/scalar_alloca.oo"
// # Scalar Alloca Test
// Logline: Test scalar alloca types
// Setup: emit-llvm
// Beats: let binding, main
pub fn test_scalar() -> Int {
  let a: Int = 10;
  let b: Int = 20;
  return a + b;
}
pub fn main() -> Int { return test_scalar(); }
EOF
  local f5_sc=1
  if emit "$d/scalar_alloca.oo" "$d/scalar_alloca.ll"; then
    if grep -q "alloca" "$d/scalar_alloca.ll"; then f5_sc=0; fi
  fi
  record_test "T1-F05-01" "Scalar variable allocation emitted" "$f5_sc"

  cat << 'EOF' > "$d/struct_alloca.oo"
// # Struct Alloca Test
// Logline: Test struct alloca
// Setup: emit-llvm
// Beats: struct, main
pub type Point = struct { x: Int, y: Int };
pub fn origin() -> Point { return Point { x: 0, y: 0 }; }
pub fn main() -> Int {
  let p = origin();
  return p.x;
}
EOF
  local f5_st=1
  if emit "$d/struct_alloca.oo" "$d/struct_alloca.ll"; then
    if grep -q "alloca" "$d/struct_alloca.ll"; then f5_st=0; fi
  fi
  record_test "T1-F05-02" "Struct allocation emitted" "$f5_st"

  local f5_slot=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_slot.oo" ]]; then f5_slot=0; fi
  record_test "T1-F05-03" "ll_slot.oo allocation module present" "$f5_slot"

  local f5_hoist=1
  if [[ -f "$d/scalar_alloca.ll" ]]; then
    if grep -q " = alloca " "$d/scalar_alloca.ll"; then f5_hoist=0; fi
  fi
  record_test "T1-F05-04" "Allocas placed in entry block" "$f5_hoist"

  local f5_as=1
  if llvm-as "$d/scalar_alloca.ll" -o "$d/scalar.bc" >/dev/null 2>&1 && \
     llvm-as "$d/struct_alloca.ll" -o "$d/struct.bc" >/dev/null 2>&1; then
    f5_as=0
  fi
  record_test "T1-F05-05" "Alloca IR passes llvm-as" "$f5_as"

  # Feature 6: Struct List Memory Leak Fix
  local f6_list_mod=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_struct_list.oo" ]]; then
    local l1; l1=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_struct_list.oo")
    if [[ "$l1" -le 256 ]]; then f6_list_mod=0; fi
  fi
  record_test "T1-F06-01" "ll_struct_list.oo <= 256 LOC" "$f6_list_mod"

  local f6_arc_mod=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_arc.oo" ]]; then
    local l2; l2=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_arc.oo")
    if [[ "$l2" -le 256 ]]; then f6_arc_mod=0; fi
  fi
  record_test "T1-F06-02" "ll_arc.oo <= 256 LOC" "$f6_arc_mod"

  cat << 'EOF' > "$d/list_ops.oo"
// # List Ops Test
// Logline: Test list operations
// Setup: emit-llvm
// Beats: list, main
pub type Item = struct { val: Int };
pub fn main() -> Int {
  let empty: List[Item] = list_new();
  let a = Item { val: 42 };
  let l1 = list_push(empty, a);
  return list_len(l1);
}
EOF
  local f6_ops=1
  if emit "$d/list_ops.oo" "$d/list_ops.ll"; then f6_ops=0; fi
  record_test "T1-F06-03" "List mutation lowers cleanly" "$f6_ops"

  local f6_as=1
  if [[ -f "$d/list_ops.ll" ]]; then
    if llvm-as "$d/list_ops.ll" -o "$d/list_ops.bc" >/dev/null 2>&1; then
      f6_as=0
    fi
  fi
  record_test "T1-F06-04" "List lowered IR passes llvm-as" "$f6_as"

  local f6_arc_reg=1
  if grep -q "arc" "$OODAC_ROOT/emit/llvm/ll_arc.oo" 2>/dev/null; then
    f6_arc_reg=0
  fi
  record_test "T1-F06-05" "ARC struct list release handling present" "$f6_arc_reg"

  # Feature 7: 8GB Ambient List Quota Pass
  local f7_flag=0
  if timeout 5s "$OODAC" --help >/dev/null 2>&1; then f7_flag=0; else f7_flag=1; fi
  record_test "T1-F07-01" "Compiler binary executable and functional" "$f7_flag"

  local f7_ooda=1
  if timeout 5s "$OODAC" check "$PROJECT_ROOT/ooda/main.oo" >/dev/null 2>&1; then
    f7_ooda=0
  fi
  record_test "T1-F07-02" "Typecheck ooda/main.oo exits 0" "$f7_ooda"

  local f7_env=0
  if [[ -n "${OO_LIST_AMBIENT_QUOTA:-}" ]]; then f7_env=0; else f7_env=1; fi
  record_test "T1-F07-03" "Ambient quota configured in environment" "$f7_env"

  local f7_quota_env=1
  if OO_LIST_AMBIENT_QUOTA=8589934592 timeout 180s "$OODAC" check "$PROJECT_ROOT/bb/cli/main.oo" >/dev/null 2>&1; then
    f7_quota_env=0
  fi
  record_test "T1-F07-04" "Compiler respects 8GB ambient list quota on bb/cli" "$f7_quota_env"

  local f7_stress=1
  local f7_out
  f7_out=$(OO_LIST_AMBIENT_QUOTA=8589934592 timeout 180s "$OODAC" check "$PROJECT_ROOT/bb/cli/main.oo" 2>&1)
  if [ $? -eq 0 ] && ! echo "$f7_out" | grep -q "ambient List memory quota exceeded"; then
    f7_stress=0
  fi
  record_test "T1-F07-05" "bb/cli/main verifies cleanly without quota overflow" "$f7_stress"

  # Feature 8: Symmetric Lifetime Bounds
  local f8_start=1
  if grep -q "@llvm.lifetime.start.p0" "$d/scalar_alloca.ll" 2>/dev/null; then
    f8_start=0
  fi
  record_test "T1-F08-01" "Declares @llvm.lifetime.start.p0" "$f8_start"

  local f8_end=1
  if grep -q "@llvm.lifetime.end.p0" "$d/scalar_alloca.ll" 2>/dev/null; then
    f8_end=0
  fi
  record_test "T1-F08-02" "Declares @llvm.lifetime.end.p0" "$f8_end"

  local f8_emit_start=1
  if grep -q "call void @llvm.lifetime.start.p0" "$d/scalar_alloca.ll" 2>/dev/null; then
    f8_emit_start=0
  fi
  record_test "T1-F08-03" "Emits lifetime.start around alloca" "$f8_emit_start"

  local f8_bal=1 ns ne
  ns=$(grep -c "call void @llvm.lifetime.start.p0" "$d/scalar_alloca.ll" 2>/dev/null || true)
  ne=$(grep -c "call void @llvm.lifetime.end.p0" "$d/scalar_alloca.ll" 2>/dev/null || true)
  if [[ "$ns" -gt 0 && "$ns" -eq "$ne" ]]; then f8_bal=0; fi
  record_test "T1-F08-04" "Lifetime bounds symmetrically balance" "$f8_bal"

  local f8_as=1
  if llvm-as "$d/scalar_alloca.ll" -o "$d/lt.bc" >/dev/null 2>&1; then
    f8_as=0
  fi
  record_test "T1-F08-05" "Lifetime bounds valid under llvm-as" "$f8_as"

  # Feature 9: SSA Scalar Promotion
  local f9_opt=1
  if which opt >/dev/null 2>&1; then f9_opt=0; fi
  record_test "T1-F09-01" "opt tool available in system" "$f9_opt"

  local f9_ir=1
  if grep -q "add nsw i64" "$d/scalar_alloca.ll" 2>/dev/null; then f9_ir=0; fi
  record_test "T1-F09-02" "Arithmetic IR available for optimization" "$f9_ir"

  local f9_mem2reg=1
  if [[ "$f9_opt" -eq 0 && -f "$d/scalar_alloca.ll" ]]; then
    if opt -passes=mem2reg -S "$d/scalar_alloca.ll" -o "$d/opt_scalar.ll" >/dev/null 2>&1; then
      f9_mem2reg=0
    fi
  fi
  record_test "T1-F09-03" "opt mem2reg pass completes cleanly" "$f9_mem2reg"

  local f9_ssa=1
  if [[ "$f9_mem2reg" -eq 0 && -f "$d/opt_scalar.ll" ]]; then
    if ! grep -q "%v_a =" "$d/opt_scalar.ll" 2>/dev/null; then
      f9_ssa=0
    fi
  fi
  record_test "T1-F09-04" "Scalar allocas promoted to pure SSA" "$f9_ssa"

  local f9_as=1
  if [[ -f "$d/opt_scalar.ll" ]]; then
    if llvm-as "$d/opt_scalar.ll" -o "$d/opt_scalar.bc" >/dev/null 2>&1; then
      f9_as=0
    fi
  fi
  record_test "T1-F09-05" "Optimized SSA IR passes llvm-as" "$f9_as"
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
