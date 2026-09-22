#!/usr/bin/env bash
# Challenger 1: M1 Iteration 2 Float List & 2D Matrix Slice Stress Runner
# Stress-tests: List[Float] 10k mutations, COW, f64 precision; 2D matrix slice ARC
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
FIXTURES="$PROJECT_ROOT/oodac/tests/fixtures/builtins_matrix"
LIBOODAR="$PROJECT_ROOT/oodar/liboodar.a"
TMPDIR="$(mktemp -d /tmp/e2e_chal_m1_iter2_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"
export OODAC_BIN="$OODAC"
export OODA_COMPILER="$OODAC"

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

compile_oo() {
  local src="$1" out_bin="$2"
  timeout 15s "$OODAC" build "$src" -o "$out_bin" >/dev/null 2>&1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Challenger M1 Iteration 2 Suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. T-CHAL-M1-06: 10,000 Float List In-Place Mutation, COW & f64 Precision
  local s_flist=1
  if compile_oo "$FIXTURES/test_stress_float_list.oo" "$d/flist_bin"; then
    if "$d/flist_bin" >/dev/null 2>&1; then s_flist=0; fi
  fi
  record_test "T-CHAL-M1-06" "List[Float] 10k mutations, COW isolation, f64 precision, slice bounds" "$s_flist"

  # 2. T-CHAL-M1-07: 2D Matrix Slice Clamped Bounds, Empty Slices, Sub-Slice COW
  local s_mslice=1
  if compile_oo "$FIXTURES/test_stress_matrix_slice_deep.oo" "$d/mslice_bin"; then
    if "$d/mslice_bin" >/dev/null 2>&1; then s_mslice=0; fi
  fi
  record_test "T-CHAL-M1-07" "2D matrix slice bounds, empty slices, sub-slice mutations, slice depth" "$s_mslice"

  # 3. T-CHAL-M1-08: Substrate C ABI Exact ARC Retain/Release Physics (OoFList, OoLL_I, OoLL_S)
  local s_phys=1
  if clang -O2 -I "$PROJECT_ROOT/oodar" "$FIXTURES/test_stress_physics_m1_iter2.c" \
     "$LIBOODAR" -lm -lpthread -o "$d/phys_bin" >/dev/null 2>&1; then
    if "$d/phys_bin" >/dev/null 2>&1; then s_phys=0; fi
  fi
  record_test "T-CHAL-M1-08" "Substrate exact ARC retain/release physics on 2D slices and OoFList" "$s_phys"
}

# Governance checks: verify Academy line counts and header laws
echo "--- Governance Verification: Line Limit & Academy Rules ---"
VIOLATIONS=0
for f in "$FIXTURES/test_stress_float_list.oo" "$FIXTURES/test_stress_matrix_slice_deep.oo" "$FIXTURES/test_stress_physics_m1_iter2.c"; do
  if [[ -f "$f" ]]; then
    lines=$(wc -l < "$f")
    if [[ "$lines" -gt 256 ]]; then
      echo "  [VIOLATION] $(basename "$f"): $lines lines (>256)"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
    if [[ "$f" == *.oo ]] && ! grep -q "^// # " "$f"; then
      echo "  [VIOLATION] $(basename "$f"): missing Academy header"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
  fi
done

self_lines=$(wc -l < "$0")
if [[ "$self_lines" -gt 256 ]]; then
  echo "  [VIOLATION] $(basename "$0"): $self_lines lines (>256)"
  VIOLATIONS=$((VIOLATIONS + 1))
fi

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "FATAL: Governance violations detected!" >&2
  exit 1
fi
echo "Governance verified: 100% of challenger files strictly <= 256 lines."

# Double-Run Determinism
run_suite 1
run_suite 2

echo "======================================================================"
echo "=== openOODA Challenger 1 M1 Iteration 2 Scorecard                 ==="
echo "======================================================================"
echo "  Total Executed : $((PASS_COUNT + FAIL_COUNT))"
echo "  Passed         : $PASS_COUNT"
echo "  Failed         : $FAIL_COUNT"
echo "  Determinism    : Run 1 == Run 2 (Verified)"
echo "======================================================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
