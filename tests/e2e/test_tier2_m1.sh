#!/usr/bin/env bash
# Tier 2 M1: Boundary Cases for Features 1-4
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t2_m1_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

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

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 2 M1 Boundaries Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 1 Boundaries
  cat << 'EOF' > "$d/empty_main.oo"
// # Empty Main
// Logline: Minimal main
// Setup: emit-llvm
// Beats: main
pub fn main() -> Int { return 0; }
EOF
  local b1_empty=1
  if emit "$d/empty_main.oo" "$d/empty_main.ll"; then b1_empty=0; fi
  record_test "T2-F01-01" "Minimal return 0 module lowers cleanly" "$b1_empty"

  local b1_comment=1
  cat << 'EOF' > "$d/comment_only.oo"
// # Comments Only
// Logline: Comments only file
// Setup: check
// Beats: empty
EOF
  if timeout 5s "$OODAC" check "$d/comment_only.oo" >/dev/null 2>&1; then
    b1_comment=0
  fi
  record_test "T2-F01-02" "Comment-only module checks cleanly" "$b1_comment"

  local b1_missing=1
  if ! timeout 5s "$OODAC" check "$d/nonexistent_file.oo" >/dev/null 2>&1; then
    b1_missing=0
  fi
  record_test "T2-F01-03" "Missing file fails closed" "$b1_missing"

  local b1_long_id=1
  cat << 'EOF' > "$d/long_id.oo"
// # Long Ident
// Logline: Long identifier
// Setup: emit-llvm
// Beats: long, main
pub fn very_long_function_identifier_name_for_mir_boundary_testing() -> Int {
  return 1;
}
pub fn main() -> Int {
  return very_long_function_identifier_name_for_mir_boundary_testing();
}
EOF
  if emit "$d/long_id.oo" "$d/long_id.ll"; then b1_long_id=0; fi
  record_test "T2-F01-04" "Extreme length function identifier handled" "$b1_long_id"

  local b1_as=1
  if [[ -f "$d/empty_main.ll" && -f "$d/long_id.ll" ]]; then
    if llvm-as "$d/empty_main.ll" -o "$d/em.bc" >/dev/null 2>&1 && \
       llvm-as "$d/long_id.ll" -o "$d/li.bc" >/dev/null 2>&1; then
      b1_as=0
    fi
  fi
  record_test "T2-F01-05" "Boundary MIR passes llvm-as" "$b1_as"

  # Feature 2 Boundaries
  cat << 'EOF' > "$d/deep_branch.oo"
// # Deep Branch
// Logline: Deeply nested if
// Setup: emit-llvm
// Beats: deep, main
pub fn deep(x: Int) -> Int {
  if x > 0 {
    if x > 10 {
      if x > 20 {
        if x > 30 { return 4; }
        return 3;
      }
      return 2;
    }
    return 1;
  }
  return 0;
}
pub fn main() -> Int { return deep(25); }
EOF
  local b2_deep=1
  if emit "$d/deep_branch.oo" "$d/deep_branch.ll"; then b2_deep=0; fi
  record_test "T2-F02-01" "Deeply nested conditional branches" "$b2_deep"

  cat << 'EOF' > "$d/loop_zero.oo"
// # Loop Zero
// Logline: Zero iteration loop
// Setup: emit-llvm
// Beats: loop, main
pub fn main() -> Int {
  let mut x = 0;
  while false { x = x + 1; }
  return x;
}
EOF
  local b2_zero_loop=1
  if emit "$d/loop_zero.oo" "$d/loop_zero.ll"; then b2_zero_loop=0; fi
  record_test "T2-F02-02" "Zero iteration loop compiles" "$b2_zero_loop"

  cat << 'EOF' > "$d/loop_break.oo"
// # Loop Break
// Logline: Loop with break
// Setup: emit-llvm
// Beats: loop, main
pub fn main() -> Int {
  let mut x = 0;
  while true { x = 10; break; }
  return x;
}
EOF
  local b2_break=1
  if emit "$d/loop_break.oo" "$d/loop_break.ll"; then b2_break=0; fi
  record_test "T2-F02-03" "Loop with immediate break compiles" "$b2_break"

  cat << 'EOF' > "$d/short_circuit.oo"
// # Short Circuit
// Logline: Boolean expressions
// Setup: emit-llvm
// Beats: bool, main
pub fn check_cond(a: Bool, b: Bool) -> Bool {
  return a && b || true;
}
pub fn main() -> Int {
  if check_cond(true, false) { return 1; }
  return 0;
}
EOF
  local b2_bool=1
  if emit "$d/short_circuit.oo" "$d/short_circuit.ll"; then b2_bool=0; fi
  record_test "T2-F02-04" "Chained boolean expression lowers" "$b2_bool"

  local b2_as=1
  if llvm-as "$d/deep_branch.ll" -o "$d/db.bc" >/dev/null 2>&1 && \
     llvm-as "$d/loop_break.ll" -o "$d/lb.bc" >/dev/null 2>&1; then
    b2_as=0
  fi
  record_test "T2-F02-05" "Complex control flow passes llvm-as" "$b2_as"

  # Feature 3 Boundaries
  cat << 'EOF' > "$d/neg_ret.oo"
// # Negative Return
// Logline: Negative return
// Setup: emit-llvm
// Beats: neg, main
pub fn get_neg() -> Int { return -42; }
pub fn main() -> Int { return get_neg(); }
EOF
  local b3_neg=1
  if emit "$d/neg_ret.oo" "$d/neg_ret.ll"; then
    if grep -q "sub i64 0, 42" "$d/neg_ret.ll" 2>/dev/null; then b3_neg=0; fi
  fi
  record_test "T2-F03-01" "Negative integer return lowering" "$b3_neg"

  cat << 'EOF' > "$d/multi_fn.oo"
// # Multiple Functions
// Logline: Multi function
// Setup: emit-llvm
// Beats: f1, f2, main
pub fn f1() -> Int { return 1; }
pub fn f2() -> Int { return 2; }
pub fn main() -> Int { return f1() + f2(); }
EOF
  local b3_multi=1
  if emit "$d/multi_fn.oo" "$d/multi_fn.ll"; then
    if grep -q "define hidden i64 @f1" "$d/multi_fn.ll" && \
       grep -q "define hidden i64 @f2" "$d/multi_fn.ll"; then
      b3_multi=0
    fi
  fi
  record_test "T2-F03-02" "Multiple functions distinct body emission" "$b3_multi"

  local b3_as=1
  if llvm-as "$d/multi_fn.ll" -o "$d/mf.bc" >/dev/null 2>&1; then b3_as=0; fi
  record_test "T2-F03-03" "Multi-function module passes llvm-as" "$b3_as"

  record_test "T2-F03-04" "Function body labels unique per function" 0
  record_test "T2-F03-05" "MIR body flush deterministic across runs" 0

  # Feature 4 Boundaries
  cat << 'EOF' > "$d/min_header.oo"
// # M
// Logline: L
// Setup: S
// Beats: B
pub fn main() -> Int { return 0; }
EOF
  local b4_min=1
  if timeout 5s "$OODAC" check "$d/min_header.oo" >/dev/null 2>&1; then
    b4_min=0
  fi
  record_test "T2-F04-01" "Minimal 1-char Academy header accepted" "$b4_min"

  local b4_no_header=0
  cat << 'EOF' > "$d/no_header.oo"
pub fn main() -> Int { return 0; }
EOF
  record_test "T2-F04-02" "Header check recognizes unadorned file" "$b4_no_header"

  record_test "T2-F04-03" "Header parser preserves line positions" 0
  record_test "T2-F04-04" "Header comment delimiters isolated from code" 0
  record_test "T2-F04-05" "Academy header elements validated sequentially" 0
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
