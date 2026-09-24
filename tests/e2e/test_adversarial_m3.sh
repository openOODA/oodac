#!/usr/bin/env bash
# Challenger 1: Adversarial M3 Stress & Falsification Suite
# Features: 10 (Symbols), 11 (Facts/Attrs), 12 (NSW), 13 (Assumes)
# Compliance: wc -l <= 256, Double-Run Determinism (Run1 == Run2 = 0)
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OODAC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
FIXTURES_DIR="$OODAC_ROOT/tests/fixtures/adversarial_m3"
TMPDIR="$(mktemp -d /tmp/challenger_m3_XXXXXX)"
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
  echo "=== Adversarial M3 Stress Suite (Run $r_id) ==="
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # PROBE 1: Cryptographic Binary Parity (Sha256)
  local p1_parity=1
  local h1 h2 h3
  h1=$(sha256sum "$HOME/.openooda/bin/oodac" | awk '{print $1}')
  h2=$(sha256sum "$OODAC_ROOT/bin/oodac" | awk '{print $1}')
  h3=$(sha256sum "$OODAC_ROOT/bin/oodac_bin.core" | awk '{print $1}')
  if [[ "$h1" == "$h2" && "$h2" == "$h3" ]]; then p1_parity=0; fi
  record "CH1-P01-01" "SHA-256 bit-for-bit parity across all 3 binaries" "$p1_parity"

  # PROBE 2: Exact Symbol Table Pruning (Feature 10)
  local p2_emit=1
  if emit "$FIXTURES_DIR/probe_symbols_pure.oo" "$d/pure.ll"; then p2_emit=0; fi
  record "CH1-P02-01" "Pure math lowers to LLVM IR" "$p2_emit"

  local p2_no_fs=1
  if ! grep -q "@oo_fs_" "$d/pure.ll" 2>/dev/null; then p2_no_fs=0; fi
  record "CH1-P02-02" "Zero @oo_fs_* declarations in pure math" "$p2_no_fs"

  local p2_no_tui=1
  if ! grep -q "@oo_tui_" "$d/pure.ll" 2>/dev/null; then p2_no_tui=0; fi
  record "CH1-P02-03" "Zero @oo_tui_* declarations in pure math" "$p2_no_tui"

  local p2_no_sys=1
  if ! grep -q "@oo_sys_" "$d/pure.ll" 2>/dev/null; then p2_no_sys=0; fi
  record "CH1-P02-04" "Zero @oo_sys_* declarations in pure math" "$p2_no_sys"

  # PROBE 3: Typechecker Facts & Attributes (Feature 11)
  local p3_attrs=1
  if grep -q "define hidden noundef i64 @transform_val(ptr noalias nocapture noundef" "$d/pure.ll" 2>/dev/null && \
     grep -q "readonly nounwind" "$d/pure.ll" 2>/dev/null; then
    p3_attrs=0
  fi
  record "CH1-P03-01" "noundef, noalias nocapture, and readonly nounwind emitted" "$p3_attrs"

  # PROBE 4: Signed NSW Arithmetic & Optimization (Feature 12)
  local p4_emit=1
  if emit "$FIXTURES_DIR/probe_nsw_loops.oo" "$d/nsw.ll"; then p4_emit=0; fi
  record "CH1-P04-01" "Signed NSW loops lower cleanly" "$p4_emit"

  local p4_nsw_ops=1
  if grep -q "mul nsw i64" "$d/nsw.ll" 2>/dev/null && \
     grep -q "add nsw i64" "$d/nsw.ll" 2>/dev/null && \
     grep -q "sub nsw i64" "$d/nsw.ll" 2>/dev/null; then
    p4_nsw_ops=0
  fi
  record "CH1-P04-02" "Emits add nsw, sub nsw, mul nsw for signed math" "$p4_nsw_ops"

  local p4_opt=1
  if opt -passes=mem2reg,instcombine -S "$d/nsw.ll" -o "$d/nsw_opt.ll" >/dev/null 2>&1; then
    # Verify instcombine folded algebraic identity (x + 10) - x to ret i64 10
    if grep -q "ret i64 10" "$d/nsw_opt.ll" 2>/dev/null; then p4_opt=0; fi
  fi
  record "CH1-P04-03" "opt mem2reg+instcombine folds signed NSW algebraic identity" "$p4_opt"

  local p4_exec=1
  if clang -O2 "$d/nsw_opt.ll" -o "$d/nsw_bin" >/dev/null 2>&1; then
    if "$d/nsw_bin"; then p4_exec=0; fi
  fi
  record "CH1-P04-04" "Optimized signed NSW binary executes and returns 0" "$p4_exec"

  # PROBE 5: Unsigned Operations Do NOT Emit NSW (Feature 12 Non-NSW)
  local p5_emit=1
  if emit "$FIXTURES_DIR/probe_nsw_unsigned.oo" "$d/unsigned.ll"; then p5_emit=0; fi
  record "CH1-P05-01" "Unsigned math lowers cleanly" "$p5_emit"

  local p5_non_nsw=1
  local u64_body
  u64_body=$(sed -n '/FN u64_math/,/FN u32_math/p' "$d/unsigned.ll" 2>/dev/null || true)
  if echo "$u64_body" | grep -q "add i64" && ! echo "$u64_body" | grep -q "add nsw"; then
    p5_non_nsw=0
  fi
  record "CH1-P05-02" "Unsigned u64 retains modular wrapping (zero nsw)" "$p5_non_nsw"

  local p5_exec=1
  if clang -O2 "$d/unsigned.ll" -o "$d/unsigned_bin" >/dev/null 2>&1; then
    if "$d/unsigned_bin"; then p5_exec=0; fi
  fi
  record "CH1-P05-03" "Unsigned math binary executes and returns 0" "$p5_exec"

  # PROBE 6: SMT Contract Assumes & Optimizer Folding (Feature 13)
  cat << 'EOF' > "$d/p6_assume.oo"
// # Proven Contract Assume
// Logline: Test assume lowering and branch folding
// Setup: emit-llvm
// Beats: f, main
pub fn proven_calc(x: Int) -> Int
  requires 100 >= 50
{
  if 50 > 100 { return 999; }
  return x * 3;
}
pub fn main() -> Int {
  let v = proven_calc(7);
  if v == 21 { return 0; }
  return 1;
}
EOF
  local p6_emit=1
  if emit "$d/p6_assume.oo" "$d/p6_assume.ll"; then p6_emit=0; fi
  record "CH1-P06-01" "Proven contract lowers cleanly" "$p6_emit"

  local p6_assume_decl=1
  if grep -q "declare void @llvm.assume(i1) nounwind" "$d/p6_assume.ll" 2>/dev/null; then
    p6_assume_decl=0
  fi
  record "CH1-P06-02" "Modern @llvm.assume declaration present" "$p6_assume_decl"

  local p6_assume_call=1
  if grep -q "call void @llvm.assume" "$d/p6_assume.ll" 2>/dev/null && \
     ! grep -q "@.con_" "$d/p6_assume.ll" 2>/dev/null; then
    p6_assume_call=0
  fi
  record "CH1-P06-03" "Emits @llvm.assume and zero dynamic trap strings" "$p6_assume_call"

  local p6_fold=1
  if opt -passes=mem2reg,instcombine,simplifycfg -S "$d/p6_assume.ll" -o "$d/p6_opt.ll" >/dev/null 2>&1; then
    # Verify optimizer folded dead branch and eliminated return 999
    if ! grep -q "999" "$d/p6_opt.ll" 2>/dev/null; then p6_fold=0; fi
  fi
  record "CH1-P06-04" "Optimizer folds redundant branch into straight-line SSA" "$p6_fold"

  local p6_exec=1
  if clang -O2 "$d/p6_opt.ll" -o "$d/p6_bin" >/dev/null 2>&1; then
    if "$d/p6_bin"; then p6_exec=0; fi
  fi
  record "CH1-P06-05" "Contract assume binary executes and returns 0" "$p6_exec"

  # PROBE 7: Academy Governance & LOC Invariants
  local p7_loc=0
  local files=(
    "emit/llvm/ll_need_tab.oo" "emit/llvm/ll_need.oo" "emit/llvm/ll_rt.oo"
    "emit/llvm/ll_int.oo" "emit/llvm/ll_call.oo"
    "emit/llvm/ll_fn.oo" "emit/llvm/ll_decl.oo" "emit/llvm/ll_contract.oo"
    "emit/llvm/ll_range.oo"
  )
  for f in "${files[@]}"; do
    local cnt
    cnt=$(wc -l < "$OODAC_ROOT/$f")
    if [[ "$cnt" -gt 256 ]]; then p7_loc=1; fi
  done
  record "CH1-P07-01" "All 9 touched M3 compiler files <= 256 LOC" "$p7_loc"

  local p7_parens=0
  if grep -E 'if\s*\(' "$OODAC_ROOT/emit/llvm/"ll_{need_tab,need,rt,int,call,fn,decl,contract,range}.oo >/dev/null 2>&1; then
    p7_parens=1
  fi
  record "CH1-P07-02" "Zero outer condition parens in touched files" "$p7_parens"

  local p7_commas=0
  if grep -E ',\s*\}' "$OODAC_ROOT/emit/llvm/"ll_{need_tab,need,rt,int,call,fn,decl,contract,range}.oo >/dev/null 2>&1; then
    p7_commas=1
  fi
  record "CH1-P07-03" "Zero struct trailing commas in touched files" "$p7_commas"
}

# Double-run determinism protocol
run_suite 1; P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2; P2=$PASS_COUNT; F2=$FAIL_COUNT

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" || "$F1" -ne 0 ]]; then
  echo "Adversarial M3 failure: Run1 ($P1/$F1) != Run2 ($P2/$F2)"
  exit 1
fi
echo "Adversarial M3 PASS: All $P1 tests passed in both runs."
exit 0
