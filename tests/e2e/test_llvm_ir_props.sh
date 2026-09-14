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

  grep -q "getelementptr inbounds" "$d/add.ll"
  record "P-GEP-01" "inbounds GEP present" "$?"
  if grep -qE 'getelementptr [^i]' "$d/add.ll"; then
    record "P-GEP-02" "no GEP without inbounds" 1
  else
    record "P-GEP-02" "no GEP without inbounds" 0
  fi

  if grep -q 'add i64 0,' "$d/add.ll" || grep -q 'fadd double 0.0,' "$d/add.ll"; then
    record "P-CONST-01" "no dummy add-zero constants" 1
  else
    record "P-CONST-01" "no dummy add-zero constants" 0
  fi

  grep -q 'declare void @oo_process_exit(i64) noreturn' "$d/add.ll"
  record "P-NORET-01" "process_exit is noreturn" "$?"

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
  llvm-as "$d/sd.ll" -o "$d/sd.bc"
  record "P-AS-02" "shift/div llvm-as" "$?"

  opt -O2 -S "$d/add.ll" -o "$d/add.opt.ll"
  record "P-OPT-01" "opt -O2 fn_ret_int" "$?"
  clang --no-default-config -c -O2 -Wno-override-module "$d/add.ll" -o "$d/add.o"
  record "P-CLANG-01" "clang -c fn_ret_int" "$?"

  python3 - "$d/add.ll" "$d/hello.ll" "$d/st.ll" "$d/ver.ll" "$d/bor.ll" "$d/sd.ll" << 'PY' && al_ok=0 || al_ok=1
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
}

run_suite 1
run_suite 2
echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
