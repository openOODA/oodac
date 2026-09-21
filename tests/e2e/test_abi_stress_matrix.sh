#!/usr/bin/env bash
# Test Suite: C-ABI Aggregate Returns & Optimization Stress Matrix
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"

TMPDIR="$(mktemp -d /tmp/test_abi_stress_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

FIXTURE_REC="$PROJECT_ROOT/oodac/tests/fixtures/test_abi_stress_recursion.oo"
FIXTURE_OPT="$PROJECT_ROOT/oodac/tests/fixtures/test_opt_side_effects.oo"
FIXTURE_LIB="$PROJECT_ROOT/oodac/tests/fixtures/test_c_abi_lib.oo"
C_HARNESS="$PROJECT_ROOT/oodac/tests/fixtures/test_c_abi_foreign_harness.c"
LIBOODAR="$PROJECT_ROOT/oodar/liboodar.a"

run_suite() {
  local r_id="$1"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. Stress Test 1: Recursive Aggregates & Niche Pointers (1000 depth)
  "$OODAC_BIN" check "$FIXTURE_REC"
  "$OODAC_BIN" emit-llvm --concat "$FIXTURE_REC" > "$d/rec.ll"

  grep -q "define hidden void @recurse_opt_some(ptr noalias sret(%OoOpt_St_MyStruct) align 8 %ret" "$d/rec.ll"
  grep -q "define hidden void @recurse_res_ok(ptr noalias sret(%OoRes_St_MyStruct) align 8 %ret" "$d/rec.ll"
  grep -q "define hidden ptr @recurse_niche_opt(i64 noundef %p_depth" "$d/rec.ll"

  for opt in -O0 -O1 -O2 -O3; do
    clang "$opt" -Wno-override-module "$d/rec.ll" "$LIBOODAR" -lm -ldl -lpthread -o "$d/rec_$opt.bin"
    "$d/rec_$opt.bin"
  done

  # 2. Stress Test 2: Side Effects & Invariant Preservation
  "$OODAC_BIN" check "$FIXTURE_OPT"
  "$OODAC_BIN" emit-llvm --concat "$FIXTURE_OPT" > "$d/side.ll"

  for opt in -O0 -O1 -O2 -O3; do
    clang "$opt" -Wno-override-module "$d/side.ll" "$LIBOODAR" -lm -ldl -lpthread -o "$d/side_$opt.bin"
    "$d/side_$opt.bin"
  done

  # 3. Stress Test 3: Foreign C SysV AMD64 ABI Boundary Harness
  "$OODAC_BIN" check "$FIXTURE_LIB"
  "$OODAC_BIN" emit-llvm "$FIXTURE_LIB" > "$d/lib.ll"

  for opt in -O0 -O1 -O2 -O3; do
    clang "$opt" -Wno-override-module "$C_HARNESS" "$d/lib.ll" "$LIBOODAR" \
        -lm -ldl -lpthread -o "$d/c_foreign_$opt.bin"
    "$d/c_foreign_$opt.bin" >/dev/null
  done
}

run_suite 1
run_suite 2

echo "=== All Stress Suites Passed Deterministically (Run 1 == Run 2 = 0) ==="
