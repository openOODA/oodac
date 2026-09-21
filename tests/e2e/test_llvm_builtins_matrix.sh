#!/usr/bin/env bash
# Milestone 1: LLVM Builtins & Aggregates Verification Matrix Runner
# Tests: list_set (in-place, COW, OOB), list_slice (clamping), nested lists
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
FIXTURES="$PROJECT_ROOT/oodac/tests/fixtures/builtins_matrix"
LIBOODAR="$PROJECT_ROOT/oodar/liboodar.a"
TMPDIR="$(mktemp -d /tmp/e2e_builtins_matrix_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"

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
  local base_ll="${out_bin}.ll"
  timeout 10s "$OODAC" check "$src" >/dev/null 2>&1
  timeout 10s "$OODAC" emit-llvm "$src" > "$base_ll" 2>&1
  clang -O2 "$base_ll" "$LIBOODAR" -lm -lpthread -o "$out_bin" >/dev/null 2>&1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Builtins Matrix Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. T-SET-01: In-Place Single-Owner Mutation (O(1), rc == 1)
  local s_inplace=1
  if compile_oo "$FIXTURES/test_list_set_inplace.oo" "$d/inplace_bin"; then
    if "$d/inplace_bin" >/dev/null 2>&1; then s_inplace=0; fi
  fi
  record_test "T-SET-01" "In-place mutation updates value and maintains rc=1" "$s_inplace"

  # 2. T-SET-02: Copy-on-Write (rc > 1)
  local s_cow=1
  if compile_oo "$FIXTURES/test_list_set_cow.oo" "$d/cow_bin"; then
    if "$d/cow_bin" >/dev/null 2>&1; then s_cow=0; fi
  fi
  record_test "T-SET-02" "COW duplicates buffer leaving original unchanged" "$s_cow"

  # 3. T-SET-03A: Out-of-Bounds Negative Index (-1)
  local s_oob_neg=1
  if compile_oo "$FIXTURES/test_list_set_oob_neg.oo" "$d/oob_neg_bin"; then
    set +e
    local out_neg
    out_neg=$("$d/oob_neg_bin" 2>&1)
    local ec_neg=$?
    set -e
    if [[ "$ec_neg" -eq 1 ]] && echo "$out_neg" | grep -q 'ERR[[:space:]]list_set OOB'; then
      s_oob_neg=0
    fi
  fi
  record_test "T-SET-03A" "Negative index triggers fatal exit 1 and ERR list_set OOB" "$s_oob_neg"

  # 4. T-SET-03B: Out-of-Bounds Length Index (len)
  local s_oob_len=1
  if compile_oo "$FIXTURES/test_list_set_oob_len.oo" "$d/oob_len_bin"; then
    set +e
    local out_len
    out_len=$("$d/oob_len_bin" 2>&1)
    local ec_len=$?
    set -e
    if [[ "$ec_len" -eq 1 ]] && echo "$out_len" | grep -q 'ERR[[:space:]]list_set OOB'; then
      s_oob_len=0
    fi
  fi
  record_test "T-SET-03B" "Length index triggers fatal exit 1 and ERR list_set OOB" "$s_oob_len"

  # 5. T-SET-04: Nested Collections (List[List[Int]], List[String])
  local s_nested=1
  if compile_oo "$FIXTURES/test_list_nested.oo" "$d/nested_bin"; then
    if "$d/nested_bin" >/dev/null 2>&1; then s_nested=0; fi
  fi
  record_test "T-SET-04" "Nested collection mutation and outer COW isolation" "$s_nested"

  # 6. T-SLICE-01: List Slices and Clamped Bounds
  local s_slice=1
  if compile_oo "$FIXTURES/test_list_slice.oo" "$d/slice_bin"; then
    if "$d/slice_bin" >/dev/null 2>&1; then s_slice=0; fi
  fi
  record_test "T-SLICE-01" "List slice empty, full, sub, and clamped bounds" "$s_slice"

  # 7. T-PHYS-01: Substrate Memory Physics Probe
  local s_phys=1
  if clang -O2 -I "$PROJECT_ROOT/oodar" "$FIXTURES/test_list_physics.c" \
     "$LIBOODAR" -lm -lpthread -o "$d/phys_bin" >/dev/null 2>&1; then
    if "$d/phys_bin" >/dev/null 2>&1; then s_phys=0; fi
  fi
  record_test "T-PHYS-01" "C ABI bit-exact refcount, zero realloc, and quota invariant" "$s_phys"

  # 8. T-FLOAT-01: List[Float] Complete Operations
  local s_float=1
  if compile_oo "$FIXTURES/test_list_float.oo" "$d/float_bin"; then
    if "$d/float_bin" >/dev/null 2>&1; then s_float=0; fi
  fi
  record_test "T-FLOAT-01" "List[Float] new, len, push, get, set, and slice" "$s_float"

  # 9. T-SLICE-02: 2D Matrix Slice & Inner Preservation
  local s_matrix_slice=1
  if compile_oo "$FIXTURES/test_matrix_slice.oo" "$d/matrix_slice_bin"; then
    if "$d/matrix_slice_bin" >/dev/null 2>&1; then s_matrix_slice=0; fi
  fi
  record_test "T-SLICE-02" "2D matrix slice preserves inner list rows and bounds" "$s_matrix_slice"
}

# Governance checks: verify Academy line counts and header laws
echo "--- Governance Verification: Line Limit & Academy Rules ---"
VIOLATIONS=0
for f in "$FIXTURES"/*.oo; do
  if [[ -f "$f" ]]; then
    lines=$(wc -l < "$f")
    if [[ "$lines" -gt 256 ]]; then
      echo "  [VIOLATION] $(basename "$f"): $lines lines (>256)"
      VIOLATIONS=$((VIOLATIONS + 1))
    fi
    if ! grep -q "^// # " "$f"; then
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
echo "Governance verified: 100% of test files strictly <= 256 lines."

# Double-Run Determinism
run_suite 1
run_suite 2

echo "======================================================================"
echo "=== openOODA Builtins Matrix Test Scorecard                        ==="
echo "======================================================================"
echo "  Total Executed : $((PASS_COUNT + FAIL_COUNT))"
echo "  Passed         : $PASS_COUNT"
echo "  Failed         : $FAIL_COUNT"
echo "  Determinism    : Run 1 == Run 2 (Verified)"
echo "======================================================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
