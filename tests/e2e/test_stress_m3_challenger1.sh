#!/usr/bin/env bash
# Challenger 1: Milestone 3 Iteration 2 Stress Test Suite
# Tests: Bounded Int Ranges (0..0, neg, extreme), Return/Param Attrs,
#        Signed NSW Arithmetic SCEV & Vectorization, Branch Pruning.
# Compliance: wc -l <= 256, Double-Run Determinism (Run1 == Run2 = 0)
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OODAC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
FIXTURES_DIR="$OODAC_ROOT/tests/fixtures/stress_m3_challenger1"
TMPDIR="$(mktemp -d /tmp/challenger_stress_m3_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-8589934592}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"

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
  echo "=== Challenger 1 Stress Suite (Run $r_id) ==="
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # PROBE 1: Binary Parity
  local p1=1
  local h1 h2 h3
  h1=$(sha256sum "$HOME/.openooda/bin/oodac" | awk '{print $1}')
  h2=$(sha256sum "$OODAC_ROOT/bin/oodac" | awk '{print $1}')
  h3=$(sha256sum "$OODAC_ROOT/bin/oodac_bin.core" | awk '{print $1}')
  if [[ "$h1" == "$h2" && "$h2" == "$h3" ]]; then p1=0; fi
  record "ST1-P01-01" "SHA-256 bit-parity across all 3 binaries" "$p1"

  # PROBE 2: Bounded Integer Edge Cases
  local p2_emit=1
  if emit "$FIXTURES_DIR/probe_bint_edge_cases.oo" "$d/bint_edge.ll"; then
    p2_emit=0
  fi
  record "ST1-P02-01" "Bounded integer edge cases lower cleanly" "$p2_emit"

  local p2_zero=1
  if grep -q "range(i64 0, 1)" "$d/bint_edge.ll" && \
     grep -q "!{i64 0, i64 1}" "$d/bint_edge.ll"; then p2_zero=0; fi
  record "ST1-P02-02" "Int[0..0] zero range emits half-open [0, 1)" "$p2_zero"

  local p2_neg=1
  if grep -q "range(i64 -100, -9)" "$d/bint_edge.ll" && \
     grep -q "!{i64 -100, i64 -9}" "$d/bint_edge.ll"; then p2_neg=0; fi
  record "ST1-P02-03" "Int[-100..-10] negative range emits [-100, -9)" "$p2_neg"

  local p2_single=1
  if grep -q "range(i64 -5, -4)" "$d/bint_edge.ll" && \
     grep -q "!{i64 -5, i64 -4}" "$d/bint_edge.ll"; then p2_single=0; fi
  record "ST1-P02-04" "Int[-5..-5] single negative point emits [-5, -4)" "$p2_single"

  local p2_ext=1
  if grep -q "!{i64 -9223372036854775807, i64 9223372036854775806}" "$d/bint_edge.ll"; then
    p2_ext=0
  fi
  record "ST1-P02-05" "Extreme 64-bit bounds lower without overflow" "$p2_ext"

  local p2_as=1
  if llvm-as "$d/bint_edge.ll" -o "$d/bint_edge.bc" >/dev/null 2>&1; then
    p2_as=0
  fi
  record "ST1-P02-06" "llvm-as validates bounded integer IR" "$p2_as"

  local p2_exec=1
  if clang "$d/bint_edge.bc" -o "$d/bint_edge_bin" >/dev/null 2>&1 && \
     "$d/bint_edge_bin"; then p2_exec=0; fi
  record "ST1-P02-07" "Bounded int edge case executable returns 0" "$p2_exec"

  # PROBE 3: Range Optimization & Dead Branch Elimination
  local p3_emit=1
  if emit "$FIXTURES_DIR/probe_bint_folding.oo" "$d/bint_fold.ll"; then
    p3_emit=0
  fi
  record "ST1-P03-01" "Range folding probe lowers cleanly" "$p3_emit"

  llvm-as "$d/bint_fold.ll" -o "$d/bint_fold.bc"
  opt -O3 -S "$d/bint_fold.bc" > "$d/bint_fold_opt.ll"

  local p3_dead=1
  if ! grep -qE "(999|888|777|666)" "$d/bint_fold_opt.ll"; then
    p3_dead=0
  fi
  record "ST1-P03-02" "opt -O3 completely prunes dead branches" "$p3_dead"

  local p3_exec=1
  if clang "$d/bint_fold_opt.ll" -o "$d/bint_fold_bin" >/dev/null 2>&1 && \
     "$d/bint_fold_bin"; then p3_exec=0; fi
  record "ST1-P03-03" "Range-folded executable returns 0" "$p3_exec"

  # PROBE 4: Signed NSW Arithmetic & SCEV Loop Folding
  local p4_emit=1
  if emit "$FIXTURES_DIR/probe_nsw_loops_scev.oo" "$d/nsw_scev.ll"; then
    p4_emit=0
  fi
  record "ST1-P04-01" "Signed NSW loop lowers cleanly" "$p4_emit"

  local p4_nsw_ops=1
  if grep -q "add nsw" "$d/nsw_scev.ll" && \
     grep -q "sub nsw" "$d/nsw_scev.ll" && \
     grep -q "mul nsw" "$d/nsw_scev.ll"; then p4_nsw_ops=0; fi
  record "ST1-P04-02" "Emits add nsw, sub nsw, mul nsw in signed loop" "$p4_nsw_ops"

  llvm-as "$d/nsw_scev.ll" -o "$d/nsw_scev.bc"
  opt -O3 -S "$d/nsw_scev.bc" > "$d/nsw_scev_opt.ll"

  local p4_scev=1
  # Under SCEV, the while loop phi node is eliminated in favor of closed-form
  if ! grep -qE "phi i64 \[ %.*, %wbody" "$d/nsw_scev_opt.ll"; then
    p4_scev=0
  fi
  record "ST1-P04-03" "opt -O3 SCEV eliminates loop via closed form" "$p4_scev"

  local p4_exec=1
  if clang "$d/nsw_scev_opt.ll" -o "$d/nsw_scev_bin" >/dev/null 2>&1 && \
     "$d/nsw_scev_bin"; then p4_exec=0; fi
  record "ST1-P04-04" "SCEV optimized signed loop executable returns 0" "$p4_exec"

  # PROBE 5: Vectorization with NSW
  cat << 'EOF' > "$d/vec_probe.ll"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
define void @vec_probe(ptr noalias nocapture %dst, ptr noalias nocapture readonly %src, i64 %n) {
entry:
  %cmp = icmp sgt i64 %n, 0
  br i1 %cmp, label %loop, label %exit
loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %p.src = getelementptr inbounds i64, ptr %src, i64 %i
  %v = load i64, ptr %p.src, align 8
  %v2 = mul nsw i64 %v, 3
  %v3 = add nsw i64 %v2, 5
  %p.dst = getelementptr inbounds i64, ptr %dst, i64 %i
  store i64 %v3, ptr %p.dst, align 8
  %i.next = add nsw i64 %i, 1
  %cond = icmp slt i64 %i.next, %n
  br i1 %cond, label %loop, label %exit
exit:
  ret void
}
EOF
  opt -O3 -S "$d/vec_probe.ll" > "$d/vec_opt.ll"
  local p5_vec=1
  if grep -q "vector.body" "$d/vec_opt.ll" && \
     grep -q "<2 x i64>" "$d/vec_opt.ll"; then p5_vec=0; fi
  record "ST1-P05-01" "Signed NSW loop vectorizes under opt -O3" "$p5_vec"

  # PROBE 6: Governance Invariants
  local p6_loc=0
  for f in "$OODAC_ROOT"/emit/llvm/ll_{call,decl,emit,fn,int,need,range,rt,ty,user_call}.oo; do
    if [[ $(wc -l < "$f") -gt 256 ]]; then p6_loc=1; break; fi
  done
  record "ST1-P06-01" "All touched M3 compiler modules <= 256 LOC" "$p6_loc"

  local p6_parens=0
  if grep -nE '(if|while)[[:space:]]+\(' \
     "$OODAC_ROOT"/emit/llvm/ll_{call,decl,emit,fn,int,need,range,rt,ty,user_call}.oo >/dev/null 2>&1; then
    p6_parens=1
  fi
  record "ST1-P06-02" "Zero condition outer parentheses in compiler" "$p6_parens"
}

run_suite 1
run_suite 2

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "Stress M3 FAIL: $FAIL_COUNT failures recorded."
  exit 1
fi

echo "Stress M3 PASS: All 18 tests passed across dual runs ($PASS_COUNT passes)."
exit 0
