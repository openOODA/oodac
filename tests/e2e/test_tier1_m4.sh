#!/usr/bin/env bash
# Tier 1 M4: Features 14-16 (Source Coordinates, FullDebug, DWARF Verify)
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OODAC_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_m4_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"

PASS_COUNT=0
FAIL_COUNT=0

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
  echo "--- Executing Tier 1 M4 (Features 14-16) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 14: Source Coordinate Threading
  cat << 'EOF' > "$d/coords.oo"
// # Coordinates Test
// Logline: Test line and column DWARF coords
// Setup: emit-llvm
// Beats: fn, main
pub fn line_two() -> Int {
  return 200;
}
pub fn main() -> Int {
  return line_two();
}
EOF
  local f14_emit=1
  if emit "$d/coords.oo" "$d/coords.ll"; then f14_emit=0; fi
  record_test "T1-F14-01" "Module with functions emits LLVM IR" "$f14_emit"

  local f14_lines=1
  if grep -q "!DILocation" "$d/coords.ll" 2>/dev/null; then
    f14_lines=0
  fi
  record_test "T1-F14-02" "DILocation metadata attached to instructions" "$f14_lines"

  local f14_cols=1
  if grep -q "column: " "$d/coords.ll" 2>/dev/null; then
    f14_cols=0
  fi
  record_test "T1-F14-03" "Column coordinates present in DILocation" "$f14_cols"

  local f14_fn_mod=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_fn.oo" ]]; then
    local l1; l1=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_fn.oo")
    if [[ "$l1" -le 256 ]]; then f14_fn_mod=0; fi
  fi
  record_test "T1-F14-04" "ll_fn.oo satisfies wc -l <= 256" "$f14_fn_mod"

  local f14_as=1
  if [[ -f "$d/coords.ll" ]]; then
    if llvm-as "$d/coords.ll" -o "$d/coords.bc" >/dev/null 2>&1; then
      f14_as=0
    fi
  fi
  record_test "T1-F14-05" "Threaded coordinate IR passes llvm-as" "$f14_as"

  # Feature 15: Industrial DWARF FullDebug
  local f15_cu=1
  if grep -q "!DICompileUnit" "$d/coords.ll" 2>/dev/null; then
    f15_cu=0
  fi
  record_test "T1-F15-01" "DICompileUnit descriptor emitted" "$f15_cu"

  local f15_ir_mod=1
  if [[ -f "$OODAC_ROOT/emit/llvm/ll_ir.oo" ]]; then
    local l2; l2=$(wc -l < "$OODAC_ROOT/emit/llvm/ll_ir.oo")
    if [[ "$l2" -le 256 ]]; then f15_ir_mod=0; fi
  fi
  record_test "T1-F15-02" "ll_ir.oo satisfies wc -l <= 256" "$f15_ir_mod"

  local f15_subp=1
  if grep -q "!DISubprogram" "$d/coords.ll" 2>/dev/null; then
    f15_subp=0
  fi
  record_test "T1-F15-03" "DISubprogram descriptors emitted for functions" "$f15_subp"

  local f15_file=1
  if grep -q "!DIFile" "$d/coords.ll" 2>/dev/null; then
    f15_file=0
  fi
  record_test "T1-F15-04" "DIFile descriptors point to source filename" "$f15_file"

  local f15_types=1
  if grep -q "!DISubroutineType" "$d/coords.ll" 2>/dev/null; then
    f15_types=0
  fi
  record_test "T1-F15-05" "DISubroutineType descriptors emitted" "$f15_types"

  # Feature 16: DWARF Validation Verification
  local f16_dwarfdump=1
  if which llvm-dwarfdump >/dev/null 2>&1; then
    f16_dwarfdump=0
  fi
  record_test "T1-F16-01" "llvm-dwarfdump tool available in environment" "$f16_dwarfdump"

  local f16_obj=1
  if [[ "$f14_as" -eq 0 && -f "$d/coords.bc" ]]; then
    if clang -c "$d/coords.bc" -o "$d/coords.o" 2>"$d/clang_err.txt"; then
      f16_obj=0
    fi
  fi
  record_test "T1-F16-02" "Object file compiles cleanly via clang" "$f16_obj"

  local f16_dump=1
  if [[ "$f16_obj" -eq 0 && -f "$d/coords.o" ]]; then
    if llvm-dwarfdump "$d/coords.o" > "$d/dump.txt" 2>&1; then
      if grep -q "DW_TAG_compile_unit" "$d/dump.txt"; then
        f16_dump=0
      fi
    fi
  fi
  record_test "T1-F16-03" "llvm-dwarfdump parses debug sections" "$f16_dump"

  local f16_no_warn=1
  if [[ "$f16_obj" -eq 0 && -f "$d/clang_err.txt" ]]; then
    if ! grep -q "ignoring invalid debug info" "$d/clang_err.txt" 2>/dev/null; then
      f16_no_warn=0
    fi
  fi
  record_test "T1-F16-04" "Zero invalid debug info warnings during compile" "$f16_no_warn"

  local f16_verify=1
  if [[ "$f16_obj" -eq 0 && -f "$d/coords.o" ]]; then
    if llvm-dwarfdump --verify "$d/coords.o" >/dev/null 2>&1; then
      f16_verify=0
    fi
  fi
  record_test "T1-F16-05" "DWARF debug sections pass --verify" "$f16_verify"
}

# Double-run determinism protocol
run_suite 1
P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
P2=$PASS_COUNT; F2=$FAIL_COUNT

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" || "$F1" -ne 0 ]]; then
  echo "Determinism failure: Run1 ($P1/$F1) != Run2 ($P2/$F2)"
  exit 1
fi
echo "Deterministic PASS: $P1 tests passed in both runs."
exit 0
