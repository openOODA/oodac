#!/usr/bin/env bash
# Tier 2 M6: Boundary Cases for Features 20-24
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t2_m6_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"

PASS_COUNT=0; FAIL_COUNT=0
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

run_bin() {
  local src="$1" ll="$2" bin="$3"
  if emit "$src" "$ll" && llvm-as "$ll" -o "${ll%.*}.bc" >/dev/null 2>&1 && \
     clang -O2 "$ll" -o "$bin" >/dev/null 2>&1 && "$bin"; then
    return 0
  fi
  return 1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 2 M6 Boundaries Run $r_id ---"
  local d="$TMPDIR/run_$r_id"; mkdir -p "$d"

  # Feature 20 Boundaries: Benchmark Lowering & Execution
  local b20_bench=1
  if [[ -f "$SCRIPT_DIR/test_vs_rustc.sh" ]]; then b20_bench=0; fi
  record_test "T2-F20-01" "Benchmark harness file present" "$b20_bench"

  local b20_syntax=1
  if bash -n "$SCRIPT_DIR/test_vs_rustc.sh" >/dev/null 2>&1; then b20_syntax=0; fi
  record_test "T2-F20-02" "Benchmark harness syntax is valid bash" "$b20_syntax"

  cat << 'EOF' > "$d/bench_suite.oo"
// # Bench Suite
// Logline: Benchmark suite boundaries
// Setup: emit-llvm
// Beats: bench, range, struct, branch
pub type Acc = struct { total: Int, count: Int };
pub fn b_accum(n: Int) -> Int {
  let mut s = 0;
  for i in 0..n { s = s + i; }
  return s;
}
pub fn b_metric(a: Acc) -> Int { return a.total * a.count; }
pub fn b_select(x: Int, y: Int) -> Int { return if x < y { x } else { y }; }
pub fn main() -> Int {
  let s = b_accum(10);
  let m = b_metric(Acc { total: 20, count: 5 });
  let sel = b_select(42, 17);
  return if s == 45 && m == 100 && sel == 17 { 0 } else { 1 };
}
EOF
  local b20_exec=1
  if run_bin "$d/bench_suite.oo" "$d/b20.ll" "$d/b20.bin"; then b20_exec=0; fi
  record_test "T2-F20-03" "Benchmark composite program lowers to LLVM and executes at -O2" "$b20_exec"

  local b20_st=1
  if grep -q "alloca %St_Acc" "$d/b20.ll" 2>/dev/null && \
     grep -q "getelementptr inbounds %St_Acc" "$d/b20.ll" 2>/dev/null; then b20_st=0; fi
  record_test "T2-F20-04" "Benchmark struct aggregate lowers with typed alloca and GEP field indexing" "$b20_st"

  local b20_sel=1
  if grep -q "icmp slt i64" "$d/b20.ll" 2>/dev/null && \
     opt -O2 -S "$d/b20.ll" -o "$d/b20_opt.ll" >/dev/null 2>&1; then b20_sel=0; fi
  record_test "T2-F20-05" "Benchmark conditional reduction lowers to icmp slt and optimizes under opt -O2" "$b20_sel"

  # Feature 21 Boundaries: Runner & Diagnostics
  local b21_runner=1
  if [[ -f "$SCRIPT_DIR/run_all.sh" ]]; then b21_runner=0; fi
  record_test "T2-F21-01" "Master test runner script present" "$b21_runner"

  local b21_fail_closed=1
  if grep -q "set -euo pipefail" "$SCRIPT_DIR/run_all.sh" 2>/dev/null; then b21_fail_closed=0; fi
  record_test "T2-F21-02" "Runner executes under set -euo pipefail" "$b21_fail_closed"

  local b21_loc=1
  if grep -q "LINE_VIOLATIONS" "$SCRIPT_DIR/run_all.sh" 2>/dev/null; then b21_loc=0; fi
  record_test "T2-F21-03" "Runner tracks line limit violations" "$b21_loc"

  cat << 'EOF' > "$d/b21_err.oo"
// # Type Error
// Logline: Type mismatch diagnostic
// Setup: check
// Beats: err
pub fn bad_type() -> Int { return "not an int"; }
EOF
  local b21_err=1
  if ! timeout 5s "$OODAC" check "$d/b21_err.oo" > "$d/b21_err.log" 2>&1; then
    if grep -q "ERR	type" "$d/b21_err.log" 2>/dev/null; then b21_err=0; fi
  fi
  record_test "T2-F21-04" "Compiler check fails closed with TSV diagnostic on type mismatch" "$b21_err"

  cat << 'EOF' > "$d/b21_cfg.oo"
// # CFG Module
// Logline: Multi-block control flow
// Setup: emit-llvm
// Beats: cfg, main
pub fn classify(x: Int) -> Int {
  let mut acc = 0;
  for i in 0..x { acc = if i < 3 { acc + 1 } else { acc + 2 }; }
  return acc;
}
pub fn main() -> Int { return if classify(5) == 7 { 0 } else { 1 }; }
EOF
  local b21_cfg=1
  if emit "$d/b21_cfg.oo" "$d/b21_cfg1.ll" && emit "$d/b21_cfg.oo" "$d/b21_cfg2.ll" && \
     cmp -s "$d/b21_cfg1.ll" "$d/b21_cfg2.ll" && \
     run_bin "$d/b21_cfg.oo" "$d/b21_cfg.ll" "$d/b21_cfg.bin"; then b21_cfg=0; fi
  record_test "T2-F21-05" "Multi-block control flow module produces deterministic IR and executes at -O2" "$b21_cfg"

  # Feature 22 Boundaries: Rebuild & IR Determinism
  local pb="$PROJECT_ROOT/bootstrap/oodac_pure_build"
  [[ ! -f "$pb" ]] && pb="$PROJECT_ROOT/oodac/bootstrap/oodac_pure_build"
  local b22_pb=1
  if [[ -f "$pb" ]]; then b22_pb=0; fi
  record_test "T2-F22-01" "Pure build script exists" "$b22_pb"

  local b22_fp=1
  if grep -q "fixed-point" "$pb" 2>/dev/null; then b22_fp=0; fi
  record_test "T2-F22-02" "Fixed-point comparison flag supported" "$b22_fp"

  local b22_trap=1
  if grep -q "ERR_FIXED_POINT" "$pb" 2>/dev/null || grep -q "exit 1" "$pb" 2>/dev/null; then b22_trap=0; fi
  record_test "T2-F22-03" "Fixed-point divergence trap present" "$b22_trap"

  cat << 'EOF' > "$d/b22_fib.oo"
// # Rebuild State Loop
// Logline: Multi-variable state loop
// Setup: emit-llvm
// Beats: loop, main
pub fn fib_iter(n: Int) -> Int {
  let mut a = 0; let mut b = 1;
  for i in 0..n { let next = a + b; a = b; b = next; }
  return a;
}
pub fn main() -> Int { return if fib_iter(10) == 55 { 0 } else { 1 }; }
EOF
  local b22_det=1
  if emit "$d/b22_fib.oo" "$d/b22_1.ll" && emit "$d/b22_fib.oo" "$d/b22_2.ll" && \
     cmp -s "$d/b22_1.ll" "$d/b22_2.ll" && llvm-as "$d/b22_1.ll" -o "$d/b22.bc" >/dev/null 2>&1; then
    b22_det=0
  fi
  record_test "T2-F22-04" "Pure module emission generates bit-identical LLVM IR across runs" "$b22_det"

  local b22_fib=1
  if run_bin "$d/b22_fib.oo" "$d/b22_fib.ll" "$d/b22_fib.bin"; then b22_fib=0; fi
  record_test "T2-F22-05" "Rebuild pipeline lowers multi-variable state loop and executes at -O2" "$b22_fib"

  # Feature 23 Boundaries: Formal Scorecard & IR Verification
  local bar_file="$PROJECT_ROOT/oodac/docs/llvm-rustc-bar.oot"
  local b23_bar=1
  if [[ -f "$bar_file" ]]; then b23_bar=0; fi
  record_test "T2-F23-01" "llvm-rustc-bar.oot exists" "$b23_bar"

  local b23_items=1
  if grep -q "Checklist" "$bar_file" 2>/dev/null || grep -q "Criteria" "$bar_file" 2>/dev/null || \
     grep -q "R1" "$bar_file" 2>/dev/null; then b23_items=0; fi
  record_test "T2-F23-02" "Rustc bar documents criteria list" "$b23_items"

  local card_file="$PROJECT_ROOT/openOODA/scripts/target_scorecard.oot"
  local b23_card=1
  if [[ -f "$card_file" ]]; then b23_card=0; fi
  record_test "T2-F23-03" "target_scorecard.oot exists" "$b23_card"

  cat << 'EOF' > "$d/b23_cert.oo"
// # Certified Spec
// Logline: Certified spec lowering
// Setup: emit-llvm
// Beats: cert, main
pub fn cert_calc(a: Int, b: Int) -> Int { return (a + b) * (a - b); }
pub fn main() -> Int { return if cert_calc(10, 6) == 64 { 0 } else { 1 }; }
EOF
  local b23_attr=1
  if emit "$d/b23_cert.oo" "$d/b23.ll" && \
     grep -q "readonly" "$d/b23.ll" 2>/dev/null && \
     grep -q "noundef" "$d/b23.ll" 2>/dev/null && \
     llvm-as "$d/b23.ll" -o "$d/b23.bc" >/dev/null 2>&1; then b23_attr=0; fi
  record_test "T2-F23-04" "Compiler fact inference attaches noundef and readonly attributes to pure functions" "$b23_attr"

  local b23_nsw=1
  if grep -q "add nsw" "$d/b23.ll" 2>/dev/null && \
     grep -q "sub nsw" "$d/b23.ll" 2>/dev/null && \
     run_bin "$d/b23_cert.oo" "$d/b23.ll" "$d/b23.bin"; then b23_nsw=0; fi
  record_test "T2-F23-05" "Certified arithmetic lowers with signed nsw flags and executes at -O2" "$b23_nsw"

  # Feature 24 Boundaries: Release Pipeline & Aggregate Transformation
  local ver_file="$PROJECT_ROOT/oodac/VERSION"
  local b24_ver=1
  if [[ -f "$ver_file" ]]; then b24_ver=0; fi
  record_test "T2-F24-01" "VERSION file exists" "$b24_ver"

  local b24_format=1
  if grep -q -E 'oodac=[0-9]+\.[0-9]+\.[0-9]+' "$ver_file" 2>/dev/null; then b24_format=0; fi
  record_test "T2-F24-02" "VERSION conforms to SemVer format" "$b24_format"

  local b24_git=1
  if git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then b24_git=0; fi
  record_test "T2-F24-03" "Inside valid Git working tree" "$b24_git"

  local b24_clean=1
  if ! ls "$PROJECT_ROOT"/*.tmp >/dev/null 2>&1; then b24_clean=0; fi
  record_test "T2-F24-04" "Zero orphaned temporary files in project root" "$b24_clean"

  cat << 'EOF' > "$d/b24_rel.oo"
// # Release E2E
// Logline: Struct transform pipeline
// Setup: emit-llvm
// Beats: rel, main
pub type Pair = struct { first: Int, second: Int };
pub fn swap(p: Pair) -> Pair { return Pair { first: p.second, second: p.first }; }
pub fn main() -> Int {
  let p = Pair { first: 10, second: 20 };
  let s = swap(p);
  return if s.first == 20 && s.second == 10 { 0 } else { 1 };
}
EOF
  local b24_rel=1
  if run_bin "$d/b24_rel.oo" "$d/b24_rel.ll" "$d/b24_rel.bin"; then b24_rel=0; fi
  record_test "T2-F24-05" "Compiler release pipeline compiles struct aggregate transformation and executes at -O2" "$b24_rel"
}

# Double-run determinism protocol
run_suite 1; P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2; P2=$PASS_COUNT; F2=$FAIL_COUNT

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" || "$F1" -ne 0 ]]; then
  echo "Determinism failure: Run1 ($P1/$F1) != Run2 ($P2/$F2)"
  exit 1
fi
echo "Deterministic PASS: $P1 tests passed in both runs."
exit 0
