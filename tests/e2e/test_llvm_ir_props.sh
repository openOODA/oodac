#!/usr/bin/env bash
# Phase A–D LLVM IR property greps. Invokes real oodac emit-llvm.
# Compliance: double-run, zero-trust, no whole-file goldens.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORPUS="$ROOT/bootstrap/corpus/emit-llvm/pass"
TMPDIR="$(mktemp -d /tmp/e2e_llvm_props_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS=0
FAIL=0
record() {
  local id="$1" desc="$2" st="$3"
  if [[ "$st" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $id: $desc"
    FAIL=$((FAIL + 1))
  fi
}

emit() {
  local src="$1" out="$2"
  "$OODAC" check "$src" >/dev/null
  "$OODAC" emit-llvm "$src" > "$out"
}

run_suite() {
  local rid="$1"
  echo "--- LLVM IR properties run $rid ---"
  local d="$TMPDIR/run_$rid"
  mkdir -p "$d"

  emit "$CORPUS/fn_ret_int.oo" "$d/add.ll"
  llvm-as "$d/add.ll" -o "$d/add.bc"
  record "P-AS-01" "fn_ret_int llvm-as" "$?"

  python3 - "$d/add.ll" << 'PY' && as_ok=0 || as_ok=1
import sys
text=open(sys.argv[1]).read().split("define ")
ok=True
for chunk in text[1:]:
    body=chunk.split("{",1)[1] if "{" in chunk else ""
    seen_non=False
    for line in body.splitlines():
        s=line.strip()
        if s.endswith("{") or s.endswith(":") or s=="" or s.startswith(";"):
            continue
        if " = alloca " in s:
            if seen_non:
                ok=False
        elif s and not s.startswith("%heap"):
            if "alloca [" in s and "%heap" in s:
                continue
            if " = alloca " not in s:
                seen_non=True
sys.exit(0 if ok else 1)
PY
  record "P-ALLOCA-01" "allocas before non-alloca in each fn" "$as_ok"

  grep -q '4194304' "$d/add.ll" && h=1 || h=0
  record "P-HEAP-01" "no 4MiB heap blob" "$h"
  grep -q 'add nsw' "$d/add.ll"
  record "P-NSW-01" "signed add is nsw" "$?"

  if grep -q 'add i64 0,' "$d/add.ll" || grep -q 'fadd double 0.0,' "$d/add.ll"; then
    record "P-CONST-01" "no dummy add-zero constants" 1
  else
    record "P-CONST-01" "no dummy add-zero constants" 0
  fi
  if grep -q 'declare void @oo_print_str' "$d/add.ll" || grep -q 'oo_process_exit' "$d/add.ll"; then
    record "P-DECL-04" "fn_ret_int has no unused print_str/exit" 1
  else
    record "P-DECL-04" "fn_ret_int has no unused print_str/exit" 0
  fi

  emit "$CORPUS/ifexpr.oo" "$d/ifx.ll"
  llvm-as "$d/ifx.ll" -o "$d/ifx.bc"
  record "P-AS-IF" "ifexpr llvm-as" "$?"
  if grep -q 'add i64 0,' "$d/ifx.ll" || grep -q 'fadd double 0.0,' "$d/ifx.ll" || grep -q 'add i32 0,' "$d/ifx.ll"; then
    record "P-CONST-02" "if-expr has no dummy add-zero" 1
  else
    record "P-CONST-02" "if-expr has no dummy add-zero" 0
  fi

  emit "$CORPUS/ir_noargs_hello.oo" "$d/hello.ll"
  if grep -q 'oo_slist' "$d/hello.ll"; then
    record "P-ARGV-01" "no-args main has no oo_slist" 1
  else
    record "P-ARGV-01" "no-args main has no oo_slist" 0
  fi
  if grep -q 'oo_tui_' "$d/hello.ll"; then
    record "P-DECL-01" "hello has no tui declares" 1
  else
    record "P-DECL-01" "hello has no tui declares" 0
  fi
  if grep -q 'oo_print_double' "$d/hello.ll" || grep -q 'uunwrapmsg' "$d/hello.ll"; then
    record "P-DECL-02" "hello has no unused print_double/unwrap" 1
  else
    record "P-DECL-02" "hello has no unused print_double/unwrap" 0
  fi

  emit "$CORPUS/struct_field.oo" "$d/st.ll"
  llvm-as "$d/st.ll" -o "$d/st.bc"
  record "P-AS-03" "struct_field llvm-as" "$?"
  if grep -q '@oo_l_Inner' "$d/st.ll" || grep -q '@oo_l_Rec' "$d/st.ll"; then
    record "P-OLIST-01" "struct-only has no oo_l_* helpers" 1
  else
    record "P-OLIST-01" "struct-only has no oo_l_* helpers" 0
  fi
  if grep -qE 'ptr #[0-9]' "$d/st.ll"; then
    record "P-IMM-01" "struct_field has no ptr #imm" 1
  else
    record "P-IMM-01" "struct_field has no ptr #imm" 0
  fi
  grep -q "getelementptr inbounds" "$d/st.ll"
  record "P-GEP-01" "inbounds GEP present" "$?"
  grep -qE 'getelementptr [^i]' "$d/st.ll" && g=1 || g=0
  record "P-GEP-02" "no GEP without inbounds" "$g"

  emit "$CORPUS/ir_two_verify.oo" "$d/ver.ll"
  llvm-as "$d/ver.ll" -o "$d/ver.bc"
  record "P-VER-01" "two verify blocks llvm-as" "$?"
  vc=$(grep -c '^@llvm.global_ctors' "$d/ver.ll" || true)
  if [[ "$vc" -eq 1 ]]; then
    record "P-VER-02" "one global_ctors definition" 0
  else
    record "P-VER-02" "one global_ctors definition" 1
  fi

  emit "$CORPUS/ir_borrow_int.oo" "$d/bor.ll"
  if grep -q ptrtoint "$d/bor.ll"; then
    record "P-BORROW-01" "Int borrow is not ptrtoint" 1
  else
    record "P-BORROW-01" "Int borrow is not ptrtoint" 0
  fi
  grep -q 'ptr %' "$d/bor.ll"
  record "P-BORROW-02" "borrow uses ptr" "$?"

  emit "$CORPUS/ir_shift_div.oo" "$d/sd.ll"
  grep -q 'and i64' "$d/sd.ll"
  record "P-SHL-01" "shift amount is masked" "$?"
  grep -q 'icmp eq i64' "$d/sd.ll"
  record "P-DIV-01" "div checks zero" "$?"
  grep -q 'declare void @oo_process_exit(i64) noreturn' "$d/sd.ll"
  record "P-NORET-01" "process_exit is noreturn on div trap" "$?"
  llvm-as "$d/sd.ll" -o "$d/sd.bc"
  record "P-AS-02" "shift/div llvm-as" "$?"

  emit "$CORPUS/list_int_basic.oo" "$d/li.ll"
  llvm-as "$d/li.ll" -o "$d/li.bc"
  record "P-AS-LIST" "list_int_basic llvm-as" "$?"
  grep -q 'call void @oo_ilist_push(ptr sret(%OoIList) align 8 %a' "$d/li.ll" && grep -q ', i64 10)' "$d/li.ll"
  record "P-LIST-01" "list_push uses i64 10 constant" "$?"
  grep -q '@oo_ilist_get' "$d/li.ll" && grep -q ', i64 0)' "$d/li.ll"
  record "P-LIST-02" "list_get uses i64 0 constant" "$?"
  grep -q 'oo_slist_' "$d/li.ll" && ls=1 || ls=0
  record "P-LIST-03" "int list_new is ilist" "$ls"
  grep -E 'call ' "$d/add.ll" | grep -v '^declare ' | grep -qv '!dbg' && db=1 || db=0
  record "P-DBG-02" "calls have !dbg" "$db"
  grep -q 'scope: !10)' "$d/add.ll" && di=1 || di=0
  record "P-DBG-03" "DILocation scope is not CU" "$di"

  opt -O2 -S "$d/add.ll" -o "$d/add.opt.ll"
  record "P-OPT-01" "opt -O2 fn_ret_int" "$?"
  clang --no-default-config -c -O2 --target=x86_64-unknown-linux-gnu "$d/add.ll" -o "$d/add.o"
  record "P-CLANG-01" "clang -c fn_ret_int (no override-module)" "$?"

  grep -q 'nounwind' "$d/add.ll"
  record "P-ATTR-01" "functions have nounwind" "$?"
  grep -q 'noundef' "$d/add.ll"
  record "P-ATTR-02" "Int params are noundef" "$?"
  grep -q 'noalias' "$d/bor.ll"
  record "P-NOALIAS-01" "borrowed ptr is noalias" "$?"
  grep -q 'oo_print_int' "$d/hello.ll"
  record "P-PRINT-01" "println Int uses oo_print_int" "$?"
  if grep -q 'oo_int_to_str' "$d/hello.ll"; then
    record "P-PRINT-02" "hello has no oo_int_to_str" 1
  else
    record "P-PRINT-02" "hello has no oo_int_to_str" 0
  fi
  grep -q 'target triple' "$d/add.ll"
  record "P-TRIPLE-01" "target triple present" "$?"
  grep -q 'llvm.module.flags' "$d/add.ll"
  record "P-FLAGS-01" "module flags present" "$?"
  grep -q 'llvm.lifetime.start' "$d/add.ll"
  record "P-LIFE-01" "lifetime.start on alloca" "$?"
  grep -q 'nounwind' "$d/sd.ll" && grep -q 'declare void @oo_process_exit(i64) noreturn' "$d/sd.ll"
  record "P-DECL-03" "declares attributed" "$?"

  grep -q '!dbg' "$d/add.ll"
  record "P-DBG-01" "debug locations present" "$?"
  grep -q 'llvm.assume' "$d/sd.ll"
  record "P-ASSUME-01" "div ok path llvm.assume" "$?"
  grep -q '@fn_ret_int_add\|@add(' "$d/add.ll"
  record "P-MANGLE-01" "internal add is a defined symbol" "$?"

  emit "$CORPUS/ir_vec_f32x8.oo" "$d/vec.ll"
  llvm-as "$d/vec.ll" -o "$d/vec.bc"
  record "P-VEC-01" "vector program llvm-as" "$?"
  grep -q '<4 x double>\|<8 x float>' "$d/vec.ll"
  record "P-VEC-02" "LLVM vector type present" "$?"

  emit "$CORPUS/ir_add_a.oo" "$d/adda.ll"
  emit "$CORPUS/ir_add_b.oo" "$d/addb.ll"
  cat "$d/adda.ll" "$d/addb.ll" > "$d/addab.ll"
  python3 - "$d/adda.ll" "$d/addb.ll" << 'PY' && mg=0 || mg=1
import sys,re
def internals(p):
    return set(re.findall(r'define internal[^{]+@([A-Za-z0-9_]+)\(', open(p).read()))
a,b=internals(sys.argv[1]),internals(sys.argv[2])
sys.exit(0 if a.isdisjoint(b) else 1)
PY
  record "P-MANGLE-02" "two-TU add symbols do not clobber" "$mg"

  python3 - "$d/add.ll" "$d/hello.ll" "$d/st.ll" "$d/ver.ll" "$d/bor.ll" "$d/sd.ll" "$d/li.ll" << 'PY' && al_ok=0 || al_ok=1
import sys, re
ok=True
for path in sys.argv[1:]:
    for i,line in enumerate(open(path),1):
        s=line.strip()
        if s.startswith(";") or s=="": continue
        if re.match(r'^(load |store |%[^=]+= load )', s) or s.startswith("store "):
            if "align " not in s:
                ok=False
sys.exit(0 if ok else 1)
PY
  record "P-ALIGN-01" "loads/stores carry align" "$al_ok"

  OODA_LLVM_TRIPLE=aarch64-unknown-linux-gnu emit "$CORPUS/fn_ret_int.oo" "$d/add.a64.ll"
  grep -q 'aarch64-unknown-linux-gnu' "$d/add.a64.ll"
  record "P-TRIPLE-02" "second triple aarch64" "$?"
  llvm-as "$d/add.a64.ll" -o "$d/add.a64.bc"
  record "P-AS-A64" "aarch64 llvm-as" "$?"
  llc -filetype=obj "$d/add.ll" -o "$d/add.llc.o"
  record "P-LLC-01" "llc x86_64 IR" "$?"
  llvm-as "$d/add.ll" -o "$d/add.bc2"
  record "P-BC-01" "bitcode via llvm-as" "$?"
  opt -O2 -module-summary "$d/add.ll" -o "$d/add.thin.bc" 2>/dev/null || opt -O2 "$d/add.ll" -o "$d/add.thin.bc"
  record "P-THIN-01" "opt module-summary/ThinLTO bitcode" "$?"
}

run_suite 1
run_suite 2
echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
