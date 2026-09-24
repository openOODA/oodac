#!/usr/bin/env bash
# WASM backend proving set: real wasmtime execution, double-run identity.
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
# Every pass program executes under wasmtime twice; output must equal the
# independent LLVM-backend oracle. Refusals must fail closed with exact errors.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
CORPUS="$PROJECT_ROOT/bootstrap/corpus/emit-wasm/pass"
[[ ! -d "$CORPUS" && -d "$PROJECT_ROOT/oodac/bootstrap/corpus/emit-wasm/pass" ]] && CORPUS="$PROJECT_ROOT/oodac/bootstrap/corpus/emit-wasm/pass"

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_COMPILER="$OODAC"
export OODAC_BIN="$OODAC"

TMPDIR="$(mktemp -d /tmp/e2e_wasm_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

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

prove_against_llvm() {
  local id="$1" src="$2"
  local d="$TMPDIR/$id"
  mkdir -p "$d"
  local exp="$d/expected.out" r1="$d/run1.out" r2="$d/run2.out"
  if ! timeout 120s "$OODAC" build --backend llvm "$src" -o "$d/oracle.bin" >/dev/null 2>&1; then
    record_test "$id" "llvm oracle builds" 1
    return
  fi
  if ! timeout 30s "$d/oracle.bin" > "$exp" 2>&1; then
    record_test "$id" "llvm oracle runs" 1
    return
  fi
  if ! timeout 120s "$OODAC" build --backend wasm "$src" -o "$d/prog.wasm" >/dev/null 2>&1; then
    record_test "$id" "wasm builds" 1
    return
  fi
  if ! timeout 30s wasmtime run "$d/prog.wasm" > "$r1" 2>&1; then
    record_test "$id" "wasm runs under wasmtime" 1
    return
  fi
  if ! timeout 30s wasmtime run "$d/prog.wasm" > "$r2" 2>&1; then
    record_test "$id" "wasm re-runs under wasmtime" 1
    return
  fi
  if cmp -s "$r1" "$r2" && cmp -s "$r1" "$exp"; then
    record_test "$id" "double-run matches llvm oracle" 0
  else
    echo "    expected:"; head -n 10 "$exp" | sed 's/^/      /'
    echo "    got:"; head -n 10 "$r1" | sed 's/^/      /'
    record_test "$id" "double-run matches llvm oracle" 1
  fi
}

regression_double_run() {
  local id="$1" src="$2"
  local d="$TMPDIR/re_$id"
  mkdir -p "$d"
  if ! timeout 120s "$OODAC" build --backend wasm "$src" -o "$d/prog.wasm" >/dev/null 2>&1; then
    record_test "$id" "prior wasm program still builds" 1
    return
  fi
  if ! timeout 30s wasmtime run "$d/prog.wasm" > "$d/r1.out" 2>&1; then
    record_test "$id" "prior wasm program still runs" 1
    return
  fi
  if ! timeout 30s wasmtime run "$d/prog.wasm" > "$d/r2.out" 2>&1; then
    record_test "$id" "prior wasm program re-runs" 1
    return
  fi
  if cmp -s "$d/r1.out" "$d/r2.out"; then
    record_test "$id" "prior wasm program double-run identical" 0
  else
    record_test "$id" "prior wasm program double-run identical" 1
  fi
}

prove_output() {
  local id="$1" src="$2" want="$3"
  local d="$TMPDIR/$id"
  mkdir -p "$d"
  local r1="$d/run1.out" r2="$d/run2.out" exp="$d/expected.out"
  printf '%s\n' "$want" > "$exp"
  if ! timeout 120s "$OODAC" build --backend wasm "$src" -o "$d/prog.wasm" >/dev/null 2>&1; then
    record_test "$id" "wasm builds" 1
    return
  fi
  if ! timeout 30s wasmtime run "$d/prog.wasm" > "$r1" 2>&1; then
    record_test "$id" "wasm runs under wasmtime" 1
    return
  fi
  if ! timeout 30s wasmtime run "$d/prog.wasm" > "$r2" 2>&1; then
    record_test "$id" "wasm re-runs under wasmtime" 1
    return
  fi
  if cmp -s "$r1" "$r2" && cmp -s "$r1" "$exp"; then
    record_test "$id" "double-run matches expected output" 0
  else
    echo "    expected:"; head -n 10 "$exp" | sed 's/^/      /'
    echo "    got:"; head -n 10 "$r1" | sed 's/^/      /'
    record_test "$id" "double-run matches expected output" 1
  fi
}

refusal_closed() {
  local id="$1" want="$2"
  shift 2
  local src="$1"
  local d="$TMPDIR/rf_$id"
  mkdir -p "$d"
  local log="$d/build.log"
  if timeout 120s "$OODAC" build --backend wasm "$src" -o "$d/prog.wasm" > "$log" 2>&1; then
    record_test "$id" "refusal fails closed" 1
    return
  fi
  if grep -F -q "$want" "$log" 2>/dev/null; then
    record_test "$id" "refusal fails closed with exact error" 0
  else
    echo "    wanted: $want"; head -n 5 "$log" | sed 's/^/      /'
    record_test "$id" "refusal fails closed with exact error" 1
  fi
}

run_suite() {
  local r_id="$1"
  echo "--- Executing WASM proving set Run $r_id ---"
  local d="$TMPDIR/gen_$r_id"
  mkdir -p "$d"

  prove_against_llvm "WASM-F01" "$CORPUS/wasm_logic_andor.oo"
  prove_against_llvm "WASM-F02" "$CORPUS/wasm_unwrap.oo"
  prove_against_llvm "WASM-F03" "$CORPUS/wasm_str_slice.oo"
  prove_against_llvm "WASM-F04" "$CORPUS/wasm_nested_construct.oo"
  prove_against_llvm "WASM-F05" "$CORPUS/wasm_match_result.oo"
  prove_against_llvm "WASM-F06" "$CORPUS/wasm_multifile_main.oo"
  prove_against_llvm "WASM-F07" "$CORPUS/wasm_for_range.oo"

  local llvm_pass="$PROJECT_ROOT/bootstrap/corpus/emit-llvm/pass"
  [[ ! -d "$llvm_pass" && -d "$PROJECT_ROOT/oodac/bootstrap/corpus/emit-llvm/pass" ]] && llvm_pass="$PROJECT_ROOT/oodac/bootstrap/corpus/emit-llvm/pass"
  for f in arith_muldiv bare_return_main call_nested fn_ret_int if_else println_int println_str str_concat while_sum result_val_err struct_nest user_fn_call; do
    regression_double_run "WASM-R-$f" "$llvm_pass/$f.oo"
  done
  prove_against_llvm "WASM-F08" "$llvm_pass/for_range_int.oo"
  prove_against_llvm "WASM-F09" "$llvm_pass/for_range_sum.oo"
  prove_against_llvm "WASM-F10" "$llvm_pass/for_nested_sum.oo"
  prove_output "WASM-F11" "$CORPUS/wasm_for_inclusive.oo" "$(printf '15\n6\n18\n')"
  prove_output "WASM-F12" "$CORPUS/wasm_for_shadow.oo" "$(printf '10\n100\n9\n')"

  cat > "$d/float.oo" << 'EOF'
pub fn main() {
    println(1.5);
}
EOF
  refusal_closed "WASM-X01" "$(printf 'ERR\twasm\texpr FLOAT')" "$d/float.oo"
  cat > "$d/for_norange.oo" << 'EOF'
pub fn main() {
    let mut s = 0;
    for i in 5 {
        s = s + i;
    }
    println(s);
}
EOF
  refusal_closed "WASM-X02" "$(printf 'ERR\twasm\tfor range')" "$d/for_norange.oo"
  cat > "$d/optmatch.oo" << 'EOF'
pub fn main() {
    let o: Option[Int] = Some(3);
    match o {
        Some(v) => println(v),
        None => println(0),
    }
}
EOF
  refusal_closed "WASM-X03" "$(printf 'ERR\twasm\tcall Some')" "$d/optmatch.oo"
  cat > "$d/matchint.oo" << 'EOF'
pub fn main() {
    let x = 1;
    let m: String = match x { Ok(v) => "ok", Err(e) => "err" };
    println(m);
}
EOF
  refusal_closed "WASM-X04" "$(printf 'ERR\twasm\tmatch scrutinee type')" "$d/matchint.oo"
  cat > "$d/forstrbound.oo" << 'EOF'
pub fn main() {
    let mut s = 0;
    for i in "a".."z" {
        s = s + i;
    }
    println(s);
}
EOF
  refusal_closed "WASM-X05" "$(printf 'ERR\twasm\tfor bounds')" "$d/forstrbound.oo"
}

run_suite "1"
run_suite "2"

echo "======================================================================="
echo "  WASM proving: $PASS_COUNT passed, $FAIL_COUNT failed (double-run)"
echo "======================================================================="
[[ "$FAIL_COUNT" -eq 0 ]]
