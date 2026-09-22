#!/usr/bin/env bash
# Test Suite: Deep Recursion & Caller Stack Frame Preservation Stress Matrix
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"

TMPDIR="$(mktemp -d /tmp/test_deep_rec_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

FIXTURE_SOV="$PROJECT_ROOT/oodac/tests/fixtures/test_deep_recursion_canaries.oo"
FIXTURE_LIB="$PROJECT_ROOT/oodac/tests/fixtures/test_c_abi_deep_recursion_lib.oo"
C_HARNESS="$PROJECT_ROOT/oodac/tests/fixtures/test_c_abi_deep_recursion_harness.c"
LIBOODAR="$PROJECT_ROOT/oodar/liboodar.a"

run_pass() {
  local r_id="$1"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. Sovereign Deep Recursion with Stack Canaries
  "$OODAC_BIN" check "$FIXTURE_SOV"
  "$OODAC_BIN" emit-llvm --concat "$FIXTURE_SOV" > "$d/sov.ll"

  grep -q "define hidden void @recurse_opt_point(ptr noalias sret(%OoOpt_St_Point) align 8 %ret" "$d/sov.ll"
  grep -q "define hidden void @recurse_res_mystruct(ptr noalias sret(%OoRes_St_MyStruct) align 8 %ret" "$d/sov.ll"

  # Build natively with oodac build
  "$OODAC_BIN" build "$FIXTURE_SOV" -o "$d/sov_native.bin"
  "$d/sov_native.bin"

  # Link across optimization matrix -O0..-O3
  for opt in -O0 -O1 -O2 -O3; do
    clang "$opt" -Wno-override-module "$d/sov.ll" "$LIBOODAR" -lm -ldl -lpthread -o "$d/sov_$opt.bin"
    "$d/sov_$opt.bin"
  done

  # 2. Foreign C-ABI Deep Recursion Foreign Harness
  "$OODAC_BIN" check "$FIXTURE_LIB"
  "$OODAC_BIN" emit-llvm "$FIXTURE_LIB" > "$d/lib.ll"

  grep -q "define default void @c_export_deep_opt(ptr noalias sret(%OoOpt_St_Point) align 8 %ret" "$d/lib.ll"
  grep -q "define default void @c_export_deep_res(ptr noalias sret(%OoRes_St_MyStruct) align 8 %ret" "$d/lib.ll"

  for opt in -O0 -O1 -O2 -O3; do
    clang "$opt" -Wno-override-module "$C_HARNESS" "$d/lib.ll" "$LIBOODAR" \
        -lm -ldl -lpthread -o "$d/c_foreign_$opt.bin"
    "$d/c_foreign_$opt.bin" >/dev/null
  done
}

run_pass 1
run_pass 2

echo "=== Deep Recursion & Caller Stack Canaries Suite: 100% PASS (Run 1 == Run 2 = 0) ==="
