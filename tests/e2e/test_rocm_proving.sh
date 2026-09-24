#!/usr/bin/env bash
# ROCm backend proving set: real gfx1100 execution, double-run identity.
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
# Every pass program executes on the GPU host twice; output must equal the
# independent LLVM-backend oracle. Refusals must fail closed with exact errors.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
CORPUS="$PROJECT_ROOT/bootstrap/corpus/emit-rocm/pass"
[[ ! -d "$CORPUS" && -d "$PROJECT_ROOT/oodac/bootstrap/corpus/emit-rocm/pass" ]] && CORPUS="$PROJECT_ROOT/oodac/bootstrap/corpus/emit-rocm/pass"

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_COMPILER="$OODAC"
export OODAC_BIN="$OODAC"
export LD_LIBRARY_PATH="/opt/rocm/lib:${LD_LIBRARY_PATH:-}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT:$(cd "$PROJECT_ROOT/.." && pwd -P):$HOME/.openooda:/opt:/etc:/tmp}"
export OODA_FS_WRITEDIR="${OODA_FS_WRITEDIR:-$PROJECT_ROOT:/tmp}"
REQ_RDIR="$PROJECT_ROOT:$(cd "$PROJECT_ROOT/.." && pwd -P):$HOME/.openooda:/opt:/etc:/tmp"
_OIFS="$IFS"; IFS=':'
for _rp in $REQ_RDIR; do
  case ":$OODA_FS_READDIR:" in *":$_rp:"*) ;; *) OODA_FS_READDIR="$OODA_FS_READDIR:$_rp";; esac
done
IFS="$_OIFS"
export OODA_FS_READDIR

cd "$PROJECT_ROOT"

TMPDIR="$(mktemp -d /tmp/e2e_rocm_XXXXXX)"
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
  if ! timeout 300s "$OODAC" build --backend rocm "$src" -o "$d/prog.bin" >/dev/null 2>&1; then
    record_test "$id" "rocm builds" 1
    return
  fi
  if ! timeout 60s "$d/prog.bin" > "$r1" 2>&1; then
    record_test "$id" "rocm runs on gfx1100" 1
    return
  fi
  if ! timeout 60s "$d/prog.bin" > "$r2" 2>&1; then
    record_test "$id" "rocm re-runs on gfx1100" 1
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

prove_double_run() {
  local id="$1" src="$2"
  local d="$TMPDIR/$id"
  mkdir -p "$d"
  if ! timeout 300s "$OODAC" build --backend rocm "$src" -o "$d/prog.bin" >/dev/null 2>&1; then
    record_test "$id" "rocm builds" 1
    return
  fi
  if ! timeout 60s "$d/prog.bin" > "$d/run1.out" 2>&1; then
    record_test "$id" "rocm runs on gfx1100" 1
    return
  fi
  if ! timeout 60s "$d/prog.bin" > "$d/run2.out" 2>&1; then
    record_test "$id" "rocm re-runs on gfx1100" 1
    return
  fi
  if cmp -s "$d/run1.out" "$d/run2.out"; then
    record_test "$id" "double-run identical on gfx1100" 0
  else
    record_test "$id" "double-run identical on gfx1100" 1
  fi
}

regression_double_run() {
  local id="$1" src="$2"
  local d="$TMPDIR/re_$id"
  mkdir -p "$d"
  if ! timeout 300s "$OODAC" build --backend rocm "$src" -o "$d/prog.bin" >/dev/null 2>&1; then
    record_test "$id" "prior rocm program still builds" 1
    return
  fi
  if ! timeout 60s "$d/prog.bin" > "$d/r1.out" 2>&1; then
    record_test "$id" "prior rocm program still runs" 1
    return
  fi
  if ! timeout 60s "$d/prog.bin" > "$d/r2.out" 2>&1; then
    record_test "$id" "prior rocm program re-runs" 1
    return
  fi
  if cmp -s "$d/r1.out" "$d/r2.out"; then
    record_test "$id" "prior rocm program double-run identical" 0
  else
    record_test "$id" "prior rocm program double-run identical" 1
  fi
}

prove_output() {
  local id="$1" src="$2" want="$3"
  local d="$TMPDIR/$id"
  mkdir -p "$d"
  local r1="$d/run1.out" r2="$d/run2.out" exp="$d/expected.out"
  printf '%s\n' "$want" > "$exp"
  if ! timeout 300s "$OODAC" build --backend rocm "$src" -o "$d/prog.bin" >/dev/null 2>&1; then
    record_test "$id" "rocm builds" 1
    return
  fi
  if ! timeout 60s "$d/prog.bin" > "$r1" 2>&1; then
    record_test "$id" "rocm runs on gfx1100" 1
    return
  fi
  if ! timeout 60s "$d/prog.bin" > "$r2" 2>&1; then
    record_test "$id" "rocm re-runs on gfx1100" 1
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
  if timeout 300s "$OODAC" build --backend rocm "$src" -o "$d/prog.bin" > "$log" 2>&1; then
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
  echo "--- Executing ROCm proving set Run $r_id ---"
  local d="$TMPDIR/gen_$r_id"
  mkdir -p "$d"

  prove_against_llvm "ROCM-F01" "$CORPUS/rocm_logic.oo"
  prove_against_llvm "ROCM-F02" "$CORPUS/rocm_unwrap.oo"
  prove_against_llvm "ROCM-F03" "$CORPUS/rocm_slice.oo"
  prove_against_llvm "ROCM-F04" "$CORPUS/rocm_nested.oo"
  prove_against_llvm "ROCM-F05" "$CORPUS/rocm_match.oo"
  prove_against_llvm "ROCM-F06" "$CORPUS/rocm_multifile_main.oo"
  prove_double_run "ROCM-F07" "$CORPUS/rocm_nested_list.oo"
  prove_against_llvm "ROCM-F08" "$CORPUS/rocm_for_range.oo"

  local llvm_pass="$PROJECT_ROOT/bootstrap/corpus/emit-llvm/pass"
  [[ ! -d "$llvm_pass" && -d "$PROJECT_ROOT/oodac/bootstrap/corpus/emit-llvm/pass" ]] && llvm_pass="$PROJECT_ROOT/oodac/bootstrap/corpus/emit-llvm/pass"
  for f in println_int println_str arith_muldiv while_sum while_if_else fn_ret_int; do
    regression_double_run "ROCM-R-$f" "$llvm_pass/$f.oo"
  done
  prove_against_llvm "ROCM-F09" "$llvm_pass/for_range_int.oo"
  prove_against_llvm "ROCM-F10" "$llvm_pass/for_range_sum.oo"
  prove_against_llvm "ROCM-F11" "$llvm_pass/for_nested_sum.oo"
  prove_output "ROCM-F12" "$CORPUS/rocm_for_inclusive.oo" "$(printf '15\n6\n18\n')"
  prove_output "ROCM-F13" "$CORPUS/rocm_for_shadow.oo" "$(printf '10\n100\n9\n')"
  prove_against_llvm "ROCM-F14" "$CORPUS/rocm_bool_print.oo"

  cat > "$d/width.oo" << 'EOF'
pub fn main() {
    let x: u32 = 41;
    if x == 41 {
        println(1);
    }
}
EOF
  refusal_closed "ROCM-X01" "$(printf 'ERR\trocm\tunsupported type u32')" "$d/width.oo"
  cat > "$d/for_norange.oo" << 'EOF'
pub fn main() {
    let mut s = 0;
    for i in 5 {
        s = s + i;
    }
    println(s);
}
EOF
  refusal_closed "ROCM-X02" "$(printf 'ERR\trocm\tfor range needs ..')" "$d/for_norange.oo"
  cat > "$d/ris.oo" << 'EOF'
pub fn main() {
    let o: Result[Int, String] = Ok(42);
    println(o.val);
}
EOF
  refusal_closed "ROCM-X03" "$(printf 'ERR\trocm\tunsupported result shape')" "$d/ris.oo"
  cat > "$d/struct.oo" << 'EOF'
pub type Rec = struct {
    x: Int
};
pub fn main() {
    let r = Rec { x: 1 };
    println(r.x);
}
EOF
  refusal_closed "ROCM-X04" "$(printf 'ERR\trocm\tunsupported type x')" "$d/struct.oo"
  cat > "$d/forstrbound.oo" << 'EOF'
pub fn main() {
    let mut s = 0;
    for i in "a".."z" {
        s = s + i;
    }
    println(s);
}
EOF
  refusal_closed "ROCM-X05" "$(printf 'ERR\trocm\tfor bounds need int')" "$d/forstrbound.oo"
}

run_suite "1"
run_suite "2"

echo "======================================================================="
echo "  ROCm proving: $PASS_COUNT passed, $FAIL_COUNT failed (double-run)"
echo "======================================================================="
[[ "$FAIL_COUNT" -eq 0 ]]
