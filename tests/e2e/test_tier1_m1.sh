#!/usr/bin/env bash
# Tier 1 M1: Features 1-4 (MIR Structures, Lowering, Flush, Headers)
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OODAC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_m1_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

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

emit() {
  local src="$1" out="$2"
  timeout 5s "$OODAC" check "$src" >/dev/null 2>&1
  timeout 5s "$OODAC" emit-llvm "$src" > "$out" 2>&1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 1 M1 (Features 1-4) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 1: In-Memory MIR Structures
  local f1_st=0
  if [[ -f "$OODAC_ROOT/emit/llvm/mir_types.oo" || \
        -f "$OODAC_ROOT/emit/llvm/ll_ir.oo" ]]; then
    f1_st=0
  else
    f1_st=1
  fi
  record_test "T1-F01-01" "MIR type module staging presence" "$f1_st"

  local f1_types_loc=0
  if [[ -f "$OODAC_ROOT/emit/llvm/mir_types.oo" ]]; then
    local l1
    l1=$(wc -l < "$OODAC_ROOT/emit/llvm/mir_types.oo")
    if [[ "$l1" -gt 256 ]]; then f1_types_loc=1; fi
  fi
  record_test "T1-F01-02" "mir_types.oo satisfies wc -l <= 256" "$f1_types_loc"

  local f1_block_loc=0
  if [[ -f "$OODAC_ROOT/emit/llvm/mir_block.oo" ]]; then
    local l2
    l2=$(wc -l < "$OODAC_ROOT/emit/llvm/mir_block.oo")
    if [[ "$l2" -gt 256 ]]; then f1_block_loc=1; fi
  fi
  record_test "T1-F01-03" "mir_block.oo satisfies wc -l <= 256" "$f1_block_loc"

  local f1_chk=0
  if [[ -f "$OODAC_ROOT/emit/llvm/anchor.oo" ]]; then f1_chk=0; else f1_chk=1; fi
  record_test "T1-F01-04" "LLVM emit anchor entrypoint present" "$f1_chk"

  local f1_hdr=0
  for f in "$OODAC_ROOT/emit/llvm"/mir_*.oo; do
    if [[ -f "$f" ]]; then
      if ! grep -q "^// # " "$f"; then f1_hdr=1; fi
    fi
  done
  record_test "T1-F01-05" "Academy header title on MIR modules" "$f1_hdr"

  # Feature 2: AST Lowering to MIR Graph
  cat << 'EOF' > "$d/ret.oo"
// # Return Test
// Logline: Simple return lowering
// Setup: emit-llvm
// Beats: compute, main
pub fn compute() -> Int { return 42; }
pub fn main() -> Int { return compute(); }
EOF
  local f2_ret=1
  if emit "$d/ret.oo" "$d/ret.ll"; then
    if grep -q "define " "$d/ret.ll" && grep -q "ret " "$d/ret.ll"; then
      f2_ret=0
    fi
  fi
  record_test "T1-F02-01" "Simple return lowered to basic block" "$f2_ret"

  cat << 'EOF' > "$d/branch.oo"
// # Branch Test
// Logline: Branch lowering
// Setup: emit-llvm
// Beats: branch, main
pub fn branch_test(x: Int) -> Int {
  if x > 10 { return 1; } else { return 0; }
}
pub fn main() -> Int { return branch_test(5); }
EOF
  local f2_br=1
  if emit "$d/branch.oo" "$d/branch.ll"; then
    if grep -q "br " "$d/branch.ll"; then f2_br=0; fi
  fi
  record_test "T1-F02-02" "Conditional branch CFG lowering" "$f2_br"

  cat << 'EOF' > "$d/loop.oo"
// # Loop Test
// Logline: Loop lowering
// Setup: emit-llvm
// Beats: loop, main
pub fn loop_test(n: Int) -> Int {
  let mut s = 0;
  let mut i = 0;
  while i < n { s = s + i; i = i + 1; }
  return s;
}
pub fn main() -> Int { return loop_test(5); }
EOF
  local f2_loop=1
  if emit "$d/loop.oo" "$d/loop.ll"; then
    if grep -q "br " "$d/loop.ll"; then f2_loop=0; fi
  fi
  record_test "T1-F02-03" "Loop lowered to CFG header/body/exit" "$f2_loop"

  cat << 'EOF' > "$d/match.oo"
// # Match Test
// Logline: Option match lowering
// Setup: emit-llvm
// Beats: match arms, main
pub fn unwrap_or(opt: Option[Int], def: Int) -> Int {
  match opt {
    Some(v) => { return v; }
    None => { return def; }
  }
}
pub fn main() -> Int {
  let o: Option[Int] = Some(42);
  return unwrap_or(o, 0);
}
EOF
  local f2_match=1
  if emit "$d/match.oo" "$d/match.ll"; then
    if llvm-as "$d/match.ll" -o "$d/match.bc" >/dev/null 2>&1; then
      f2_match=0
    fi
  fi
  record_test "T1-F02-04" "Pattern match lowered to valid CFG" "$f2_match"

  local f2_as=1
  if llvm-as "$d/ret.ll" -o "$d/ret.bc" >/dev/null 2>&1 && \
     llvm-as "$d/branch.ll" -o "$d/branch.bc" >/dev/null 2>&1 && \
     llvm-as "$d/loop.ll" -o "$d/loop.bc" >/dev/null 2>&1; then
    f2_as=0
  fi
  record_test "T1-F02-05" "Lowered MIR passes llvm-as validation" "$f2_as"

  # Feature 3: Sole Function-Body MIR Printer
  local f3_file=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_ir_flush.oo" ]]; then f3_file=0; fi
  record_test "T1-F03-01" "ll_ir_flush.oo exists in emit/llvm" "$f3_file"

  local f3_loc=1
  if [[ "$f3_file" -eq 0 ]]; then
    local lines
    lines=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_ir_flush.oo")
    if [[ "$lines" -le 256 ]]; then f3_loc=0; fi
  fi
  record_test "T1-F03-02" "ll_ir_flush.oo satisfies wc -l <= 256" "$f3_loc"

  local f3_raw=0
  if grep -E '^\s*T\\t' "$d/ret.ll" 2>/dev/null; then f3_raw=1; fi
  record_test "T1-F03-03" "Zero raw T\\t records in emitted bodies" "$f3_raw"

  local f3_inst=1
  if grep -q "ret i64 42" "$d/ret.ll" 2>/dev/null; then f3_inst=0; fi
  record_test "T1-F03-04" "Direct MIR structured instruction emission" "$f3_inst"
  local f3_det=1
  if emit "$d/ret.oo" "$d/ret2.ll" && cmp -s "$d/ret.ll" "$d/ret2.ll"; then f3_det=0; fi
  record_test "T1-F03-05" "MIR flush produces deterministic output" "$f3_det"

  # Feature 4: Academy Header Compliance
  local f4_expr=1
  if grep -q "^// # " "$OODAC_ROOT/emit/llvm/ll_expr.oo"; then f4_expr=0; fi
  record_test "T1-F04-01" "ll_expr.oo has title header" "$f4_expr"

  local f4_ty=1
  if grep -q "^// # " "$OODAC_ROOT/emit/llvm/ll_ty.oo"; then f4_ty=0; fi
  record_test "T1-F04-02" "ll_ty.oo has title header" "$f4_ty"

  local f4_expr_log=1
  if grep -q "^// Logline:" "$OODAC_ROOT/emit/llvm/ll_expr.oo"; then
    f4_expr_log=0
  fi
  record_test "T1-F04-03" "ll_expr.oo has Logline header" "$f4_expr_log"

  local f4_ty_log=1
  if grep -q "^// Logline:" "$OODAC_ROOT/emit/llvm/ll_ty.oo"; then
    f4_ty_log=0
  fi
  record_test "T1-F04-04" "ll_ty.oo has Logline header" "$f4_ty_log"

  local f4_all_titles=0
  for f in "$OODAC_ROOT/emit/llvm"/*.oo; do
    if ! grep -q "^// # " "$f"; then f4_all_titles=1; break; fi
  done
  record_test "T1-F04-05" "All emit/llvm modules have title headers" "$f4_all_titles"
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
