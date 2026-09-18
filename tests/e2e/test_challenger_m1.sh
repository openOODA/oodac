#!/usr/bin/env bash
# # Challenger 1 Empirical Verification Suite for Milestone 1 (Structured MIR)
#
# Logline: Stress-test MIR graph traversal across loops, nested matches, and IR validity.
#
# Setup: Tests deep CFG traversal, verifies opt/llc, asserts zero raw T\t records.
#
# Beats:
#   1. Stress-test multi-level nested loops with break and continue.
#   2. Stress-test nested match statements with Option/Result variants.
#   3. Stress-test loop-enclosed matches with arm-level break/continue.
#   4. Validate LLVM IR with llvm-as, opt -O2, and llc.
#   5. Assert zero raw T\t records inside function bodies.
#   6. Enforce double-run determinism (Run 1 == Run 2).

set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/challenger_m1_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OODA_COMPILER="$OODAC"
export OODAC_BIN="$OODAC"
export OODA_NO_JAIL=1
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"

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
  timeout 10s "$OODAC" check "$src" >/dev/null 2>&1
  timeout 10s "$OODAC" emit-llvm "$src" > "$out" 2>&1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Challenger M1 Suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Test 1: Multi-level nested loops with break & continue
  cat << 'EOF' > "$d/stress_loops.oo"
// # Stress Nested Loops
// Logline: Multi-level loops with early break and continue
// Setup: emit-llvm
// Beats: loops, main
pub fn compute(limit: Int) -> Int {
  let mut total: Int = 0;
  let mut i: Int = 0;
  while i < limit {
    i = i + 1;
    if i == 3 { continue; }
    if i == 8 { break; }
    let mut j: Int = 0;
    while j < 4 {
      j = j + 1;
      if j == 2 { continue; }
      let mut k: Int = 0;
      while k < 3 {
        k = k + 1;
        if k == 2 { break; }
        total = total + i * 100 + j * 10 + k;
      }
    }
  }
  return total;
}
pub fn main() -> Int {
  let res: Int = compute(10);
  println(res);
  return 0;
}
EOF
  local s1=1
  if emit "$d/stress_loops.oo" "$d/stress_loops.ll"; then
    if llvm-as "$d/stress_loops.ll" -o "$d/stress_loops.bc" >/dev/null 2>&1 && \
       opt -O2 "$d/stress_loops.bc" -o "$d/stress_loops_opt.bc" >/dev/null 2>&1 && \
       llc "$d/stress_loops_opt.bc" -o "$d/stress_loops.s" >/dev/null 2>&1 && \
       "$OODAC" build "$d/stress_loops.oo" -o "$d/stress_loops.bin" >/dev/null 2>&1; then
      local out
      out=$("$d/stress_loops.bin")
      if [[ "$out" == *"7998"* ]]; then s1=0; fi
    fi
  fi
  record_test "CHAL-M1-01" "Nested loops (3-deep) break/continue parity (7998)" "$s1"

  # Test 2: Nested match statements with Result and Option
  cat << 'EOF' > "$d/stress_matches.oo"
// # Stress Nested Matches
// Logline: Nested Result and Option statement match
// Setup: emit-llvm
// Beats: matches, main
pub fn evaluate(flag: Bool, x: Int) -> Int {
  let r: Result[Int, String] = if flag { Ok(x) } else { Err("err") };
  let mut res: Int = 0;
  match r {
    Ok(v) => {
      let opt: Option[Int] = if v > 10 { Some(v * 2) } else { None };
      match opt {
        Some(w) => { res = w + 5; },
        None => { res = v - 3; }
      }
    },
    Err(e) => { res = -1; }
  }
  return res;
}
pub fn main() -> Int {
  let v1: Int = evaluate(true, 15);
  let v2: Int = evaluate(true, 5);
  let v3: Int = evaluate(false, 0);
  println(v1);
  println(v2);
  println(v3);
  return 0;
}
EOF
  local s2=1
  if emit "$d/stress_matches.oo" "$d/stress_matches.ll"; then
    if llvm-as "$d/stress_matches.ll" -o "$d/stress_matches.bc" >/dev/null 2>&1 && \
       opt -O2 "$d/stress_matches.bc" -o "$d/stress_matches_opt.bc" >/dev/null 2>&1 && \
       llc "$d/stress_matches_opt.bc" -o "$d/stress_matches.s" >/dev/null 2>&1 && \
       "$OODAC" build "$d/stress_matches.oo" -o "$d/stress_matches.bin" >/dev/null 2>&1; then
      local out
      out=$("$d/stress_matches.bin")
      if [[ "$out" == *"35"* && "$out" == *"2"* && "$out" == *"-1"* ]]; then s2=0; fi
    fi
  fi
  record_test "CHAL-M1-02" "Nested match lowering & opt-O2 pipeline (35, 2, -1)" "$s2"

  # Test 3: Loop-enclosed match with continue and break
  cat << 'EOF' > "$d/stress_loop_match.oo"
// # Stress Loop Match
// Logline: Loop containing match with arm-level continue
// Setup: emit-llvm
// Beats: loop_match, main
pub fn process_batch(n: Int) -> Int {
  let mut sum: Int = 0;
  let mut i: Int = 0;
  while i < n {
    i = i + 1;
    let r: Result[Int, String] = if i % 2 == 0 { Ok(i * 10) } else { Err("odd") };
    match r {
      Ok(v) => {
        if v == 40 { continue; }
        sum = sum + v;
      },
      Err(msg) => { continue; }
    }
    sum = sum + 100;
  }
  return sum;
}
pub fn main() -> Int {
  let ans: Int = process_batch(6);
  println(ans);
  return 0;
}
EOF
  local s3=1
  if emit "$d/stress_loop_match.oo" "$d/stress_loop_match.ll"; then
    if llvm-as "$d/stress_loop_match.ll" -o "$d/stress_loop_match.bc" >/dev/null 2>&1 && \
       opt -O2 "$d/stress_loop_match.bc" -o "$d/stress_loop_match_opt.bc" >/dev/null 2>&1 && \
       llc "$d/stress_loop_match_opt.bc" -o "$d/stress_loop_match.s" >/dev/null 2>&1 && \
       "$OODAC" build "$d/stress_loop_match.oo" -o "$d/stress_loop_match.bin" >/dev/null 2>&1; then
      local out
      out=$("$d/stress_loop_match.bin")
      if [[ "$out" == *"280"* ]]; then s3=0; fi
    fi
  fi
  record_test "CHAL-M1-03" "Loop-enclosed match arm continue (oracle 280)" "$s3"

  # Test 4: Assert zero raw T\t in function bodies of all stress tests
  local s4=0
  for ll in "$d"/*.ll; do
    if grep -P '^\s*T\t' "$ll" 2>/dev/null; then s4=1; fi
  done
  record_test "CHAL-M1-04" "Zero raw T\\t records in stress test LLVM IR bodies" "$s4"

  # Test 5: Corpus-wide programmatic scan for zero raw T\t inside function bodies
  local s5=0
  local corpus_count=0
  for cf in "$PROJECT_ROOT/oodac/bootstrap/corpus/emit-llvm/pass"/*.oo; do
    local bname
    bname=$(basename "$cf")
    if emit "$cf" "$d/corpus_$bname.ll" 2>/dev/null; then
      corpus_count=$((corpus_count + 1))
      if grep -P '^\s*T\t' "$d/corpus_$bname.ll" 2>/dev/null; then
        s5=1
        break
      fi
    fi
  done
  record_test "CHAL-M1-05" "Zero raw T\\t in function bodies across $corpus_count corpus files" "$s5"

  # Test 6: Purged string-scanning functions invariant in ll_ir_flush.oo
  local s6=0
  if grep -E "ll_t_is_call|ll_t_is_label|ll_is_hdr|ll_fn_scope|ll_collect_a|field_at|ll_nl|ll_each_a|ll_dump_as|ll_flush_fn" \
      "$PROJECT_ROOT/oodac/emit/llvm/ll_ir_flush.oo" >/dev/null 2>&1; then
    s6=1
  fi
  record_test "CHAL-M1-06" "10 legacy string heuristics purged from ll_ir_flush.oo" "$s6"
}

# Double-run determinism protocol
run_suite 1
P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
P2=$PASS_COUNT; F2=$FAIL_COUNT

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" || "$F1" -ne 0 ]]; then
  echo "Challenger Determinism failure: Run1 ($P1/$F1) != Run2 ($P2/$F2)"
  exit 1
fi

echo "Deterministic Challenger PASS: $P1 tests passed in both runs."
exit 0
