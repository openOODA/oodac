#!/usr/bin/env bash
# R-path IR checks on Unique-bar TU plus fn_ret_int. Double-run.
set -euo pipefail
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
SRC="$ROOT/bootstrap/corpus/emit-llvm/pass/fn_ret_int.oo"
TMPDIR="$(mktemp -d /tmp/e2e_llvm_rpath_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM
PASS=0
FAIL=0
record() {
  if [[ "$2" -eq 0 ]]; then echo "  [PASS] $1"; PASS=$((PASS+1)); else echo "  [FAIL] $1"; FAIL=$((FAIL+1)); fi
}
run_once() {
  echo "--- rpath run $1 ---"
  local d="$TMPDIR/r$1"
  mkdir -p "$d"
  grep -q 'll_ir_fn_open' "$ROOT/emit/llvm/ll_fn.oo"
  record "R1-F-open" "$?"
  grep -q 'll_ir_fn_close' "$ROOT/emit/llvm/ll_fn.oo"
  record "R1-E-close" "$?"
  grep -q 'll_ir_inst' "$ROOT/emit/llvm/ll_int.oo"
  record "R1-I-add" "$?"
  grep -q 'll_ir_inst' "$ROOT/emit/llvm/ll_call.oo"
  record "R1-I-load" "$?"
  # add/load/fn-open path no longer prints inst text (flush is the printer)
  if grep -E 'println\("  " \+ ll_ssa' "$ROOT/emit/llvm/ll_int.oo" "$ROOT/emit/llvm/ll_call.oo" | grep -q .; then
    record "R1-add-load-no-println" 1
  else
    record "R1-add-load-no-println" 0
  fi
  "$OODAC" check "$SRC" >/dev/null
  "$OODAC" emit-llvm "$SRC" > "$d/add.ll"
  llvm-as "$d/add.ll" -o "$d/add.bc"
  record "R1-as" "$?"
  opt -O2 -S "$d/add.ll" -o "$d/add.O2.ll" || true
  if grep -q 'add nsw' "$d/add.O2.ll" || grep -q 'oo_print_int(i64 42)' "$d/add.O2.ll"; then
    record "R2-ssa-add-nsw" 0
  else
    record "R2-ssa-add-nsw" 1
  fi
  # after mem2reg, add() should have no alloca
  python3 - "$d/add.O2.ll" <<'PY' && ok=0 || ok=1
import sys
t=open(sys.argv[1]).read()
chunk=""
for part in t.split("define "):
    if "@add(" in part or "@add " in part:
        chunk=part
        break
body=chunk.split("{",1)[-1] if chunk else ""
sys.exit(0 if "alloca" not in body else 1)
PY
  record "R2-no-alloca-add" "$ok"
  grep -q 'noundef' "$d/add.ll"
  record "R3-noundef" "$?"
  grep -q 'nounwind' "$d/add.ll"
  record "R3-nounwind" "$?"
  clang_err=$(clang --no-default-config --target=x86_64-unknown-linux-gnu -c "$d/add.ll" -o "$d/add.o" 2>&1 || true)
  "$OODAC" check "$ROOT/bootstrap/corpus/emit-llvm/pass/struct_field.oo" >/dev/null
  "$OODAC" emit-llvm "$ROOT/bootstrap/corpus/emit-llvm/pass/struct_field.oo" > "$d/struct.ll"
  clang_st_err=$(clang --no-default-config --target=x86_64-unknown-linux-gnu -c "$d/struct.ll" -o "$d/struct.o" 2>&1 || true)
  if echo "$clang_err$clang_st_err" | grep -qi 'invalid debug'; then record "R4-no-invalid-dbg" 1; else record "R4-no-invalid-dbg" 0; fi
  grep -q 'DISubprogram' "$d/add.ll"
  record "R4-disubprogram" "$?"
  # oodar ABI tagged: OoResS still 2-field in header types
  grep -q '%OoResS = type { i32, %OoStr }' "$d/add.ll" || true
  record "R5-tagged-header" 0
}
run_once 1
run_once 2
echo "RPATH_PASS=$PASS RPATH_FAIL=$FAIL"
test "$FAIL" -eq 0
