#!/usr/bin/env bash
# Test Suite: C-ABI Aggregate Returns & Sovereign Niche Pointers
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"

TMPDIR="$(mktemp -d /tmp/test_abi_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

FIXTURE_SOV="$PROJECT_ROOT/oodac/tests/fixtures/test_abi_aggregates.oo"
FIXTURE_CLIB="$PROJECT_ROOT/oodac/tests/fixtures/test_c_abi_lib.oo"
C_HARNESS="$PROJECT_ROOT/oodac/tests/fixtures/test_c_abi_foreign_harness.c"
LIBOODAR="$PROJECT_ROOT/oodar/liboodar.a"

run_pass() {
  local r_id="$1"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. Sovereign Aggregates & Niche Pointers
  "$OODAC_BIN" check "$FIXTURE_SOV"
  "$OODAC_BIN" emit-llvm "$FIXTURE_SOV" > "$d/sov.ll"

  grep -q "define hidden void @make_opt(ptr noalias sret(%OoOpt_St_MyStruct) align 8 %ret" "$d/sov.ll"
  grep -q "define hidden void @make_res(ptr noalias sret(%OoRes_St_MyStruct) align 8 %ret" "$d/sov.ll"
  grep -q "define hidden ptr @sovereign_opt_ref(" "$d/sov.ll"
  grep -q "define hidden ptr @sovereign_res_ref(" "$d/sov.ll"

  "$OODAC_BIN" build "$FIXTURE_SOV" -o "$d/sov.bin"
  "$d/sov.bin"

  # 2. Foreign C-ABI Library & Harness
  "$OODAC_BIN" check "$FIXTURE_CLIB"
  "$OODAC_BIN" emit-llvm "$FIXTURE_CLIB" > "$d/clib.ll"

  grep -q "define default void @c_export_make_opt(ptr noalias sret(%OoOpt_St_MyStruct) align 8 %ret" "$d/clib.ll"
  grep -q "define default void @c_export_make_res(ptr noalias sret(%OoRes_St_MyStruct) align 8 %ret" "$d/clib.ll"
  grep -q "define default void @c_export_opt_ref(ptr noalias sret(%OoOpt_Ptr) align 8 %ret" "$d/clib.ll"

  clang -O2 -Wno-override-module "$C_HARNESS" "$d/clib.ll" "$LIBOODAR" \
      -lm -ldl -lpthread -o "$d/c_harness.bin"
  "$d/c_harness.bin" >/dev/null
}

run_pass 1
run_pass 2

echo "T-AGG-01: Sovereign Aggregates & Niche Pointers [PASS]"
echo "T-AGG-02: Foreign C-ABI Aggregates & Sret Marshalling [PASS]"
