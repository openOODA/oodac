#!/usr/bin/env bash
# # Non-LLVM backend ratchet probe (Audit 15)
# Why bash not .oo: drives host oodac + node WASI + python struct checks
# (host-tooling exception, cf. bootstrap/oodac_pure_build).
# job: differential gate for --backend elf / wasm / rocm against the LLVM
#      oracle. OK-listed fixtures must match LLVM stdout bytes; CLOSED-listed
#      fixtures must exit nonzero (fail closed, never silently miscompile).
#      ROCm asserts HIP emission only (no hipcc/AMD GPU on CI hosts).
# in:  backend_sweep.sh <host-oodac>
#      Caller sets OODA_COMPILER/OODAC_BIN + OODA_FS_READDIR/WRITEDIR.
# out: one line per case; exit 0 iff no WRONG and no unexpected CLOSED.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOST="${1:?usage: backend_sweep.sh <host-oodac}"
if [[ "$HOST" != /* ]]; then HOST="$(pwd)/$HOST"; fi
PASS="$ROOT/bootstrap/corpus/emit-llvm/pass"
TMP="${SWEEP_TMP:-.ooda-cache/ooda-tmp/sweep}"
mkdir -p "$TMP"
fails=0

node_bin() {
  command -v node 2>/dev/null || ls /usr/local/bin/node 2>/dev/null || ls /opt/node*/bin/node 2>/dev/null | head -1
}

NODE="$(node_bin || true)"
if [[ -z "${NODE:-}" ]]; then echo "ERR sweep node missing (ubuntu-latest ships node; check PATH)"; exit 1; fi

run_wasm() {
  "$NODE" --experimental-wasi-unstable-preview1 -e '
const fs=require("fs");const {WASI}=require("node:wasi");
const wasi=new WASI({version:"preview1"});
WebAssembly.instantiate(fs.readFileSync(process.argv[1]),{wasi_snapshot_preview1:wasi.getImportObject().wasi_snapshot_preview1}).then(({instance})=>{try{wasi.start(instance);}catch(e){if(e.code===undefined||e.code===0)return;process.exit(e.code);}});' "$1" 2>/dev/null
}

# python struct check: magic + version + section walk (catches truncation).
wasm_struct_ok() {
  python3 -c '
import struct,sys
b=open(sys.argv[1],"rb").read()
assert b[:4]==b"\x00asm" and b[4:8]==b"\x01\x00\x00\x00",(len(b))
i=8
while i < len(b):
  sid=b[i];i+=1
  n=shift=0
  while True:
    b7=b[i];i+=1;n|=(b7&0x7F)<<shift
    if not b7&0x80:break
    shift+=7
  i+=n
assert i==len(b),(i,len(b))
print("STRUCT-OK",len(b))
' "$1"
}

oracle() { # $1=base -> stdout of LLVM build
  timeout 120 "$HOST" build --backend llvm "$PASS/$1.oo" -o "$TMP/$1.llvm" >/dev/null 2>&1 || { echo "ERR sweep no LLVM oracle for $1"; return 1; }
  timeout 10 "$TMP/$1.llvm" 2>/dev/null
}

elf_ok() { # $1=base must match oracle
  local exp got
  exp="$(oracle "$1")" || { fails=$((fails+1)); return; }
  if timeout 120 "$HOST" build --backend elf "$PASS/$1.oo" -o "$TMP/$1.elf" >/dev/null 2>&1; then
    got="$(timeout 10 "$TMP/$1.elf" 2>/dev/null)"
    if [[ "$got" == "$exp" ]]; then echo "OK elf $1"; else echo "WRONG elf $1: got [$got] want [$exp]"; fails=$((fails+1)); fi
  else echo "UNEXPECTED-CLOSED elf $1 (rc=$?)"; fails=$((fails+1)); fi
}

wasm_ok() { # $1=base must match oracle under node WASI
  local exp got
  exp="$(oracle "$1")" || { fails=$((fails+1)); return; }
  if timeout 120 "$HOST" build --backend wasm "$PASS/$1.oo" -o "$TMP/$1.wasm" >/dev/null 2>&1; then
    wasm_struct_ok "$TMP/$1.wasm" >/dev/null || { echo "WRONG wasm $1: struct invalid"; fails=$((fails+1)); return; }
    got="$(run_wasm "$TMP/$1.wasm" 2>/dev/null)"
    if [[ "$got" == "$exp" ]]; then echo "OK wasm $1"; else echo "WRONG wasm $1: got [$got] want [$exp]"; fails=$((fails+1)); fi
  else echo "UNEXPECTED-CLOSED wasm $1 (rc=$?)"; fails=$((fails+1)); fi
}

closed() { # $1=backend $2=src must exit nonzero (never silently miscompile)
  if timeout 120 "$HOST" build --backend "$1" "$2" -o "$TMP/closed.out" >/dev/null 2>&1; then
    echo "UNEXPECTED-OK $1 $2 (fail-closed row built; verify output manually)"; fails=$((fails+1))
  else rc=$?; echo "OK $1-closed $(basename "$2") (rc=$rc)"; fi
}

echo "=== Audit 15 backend sweep ==="
for f in fn_ret_int verify_ctor; do elf_ok "$f"; done
for f in println_str bool_print list_get; do closed elf "$PASS/$f.oo"; done
for f in fn_ret_int println_str str_concat if_else while_sum for_range_sum for_nested_sum \
         list_get list_int_basic match_ok match_stmt match_assign match_result_let \
         result_ok_err result_val_err struct_field struct_list user_fn_call \
         fn_ret_string arith_muldiv bool_print ensures_complex verify_ctor; do wasm_ok "$f"; done
closed wasm "$ROOT/qa/probe_list_ok.oo"
for f in method_calls float_arith float_calls str_starts_with str_escapes str_match_stmt \
         multi_diamond ifexpr ifexpr_break ifexpr_multi ifexpr_strnest ifexpr_unit \
         width_ints width_struct_for cap_spread cap_spread2 export_fn for_int_bound; do closed wasm "$PASS/$f.oo"; done

echo "=== cuda emission (full exec needs nvcc; CI asserts emission) ==="
rm -f .ooda-cache/ooda-tmp/cuda_*.cu
if timeout 120 "$HOST" build --backend cuda "$PASS/fn_ret_int.oo" -o "$TMP/cuda_fn.bin" >/dev/null 2>&1; then
  got="$("$TMP/cuda_fn.bin" 2>/dev/null)"
  if [[ "$got" == "42" ]]; then echo "OK cuda-exec fn_ret_int (nvcc present, prints 42)";
  else echo "WRONG cuda-exec fn_ret_int: got [$got] want [42]"; fails=$((fails+1)); fi
else
  if command -v nvcc >/dev/null 2>&1; then
    echo "WRONG cuda build failed WITH nvcc present (broken .cu or link)"; fails=$((fails+1))
  else
    cu=$(ls -t .ooda-cache/ooda-tmp/cuda_*.cu 2>/dev/null | head -1)
    if [[ -n "${cu:-}" ]] && grep -q "int main" "$cu" && grep -q "cuda_runtime.h" "$cu"; then
      echo "OK cuda-emit fn_ret_int (no nvcc here; .cu with main + cuda_runtime)"
    else echo "WRONG cuda-emit: no .cu artifact"; fails=$((fails+1)); fi
  fi
fi

echo "=== rocm emission (no hipcc on CI hosts) ==="
rm -f "$TMP"/rocm_*.hip
timeout 120 "$HOST" build --backend rocm "$PASS/fn_ret_int.oo" -o "$TMP/rocm.out" >/dev/null 2>&1
rc=$?
hip=$(ls -t .ooda-cache/ooda-tmp/rocm_*.hip 2>/dev/null | head -1)
if [[ -n "${hip:-}" ]] && grep -q "int main" "$hip"; then
  echo "OK rocm-emit fn_ret_int (build rc=$rc, $(wc -l < "$hip")-line HIP with main)"
else echo "WRONG rocm-emit: no HIP artifact"; fails=$((fails+1)); fi

if [[ "$fails" == "0" ]]; then echo "SWEEP OK"; else echo "SWEEP FAIL: $fails"; fi
exit "$fails"
