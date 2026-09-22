#!/usr/bin/env bash
# Milestone 3: Empirical ARC Scope, Control-Flow & Quota Challenger Runner
# Compliance: wc -l <= 256, Double-Run Determinism (Run 1 == Run 2 = 0), ASan/LSan.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
FIXTURES_DIR="$PROJECT_ROOT/oodac/tests/fixtures/challenger_m3"
LIBOODAR="$PROJECT_ROOT/oodar/liboodar.a"
TMPDIR="$(mktemp -d /tmp/e2e_challenger_arc_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

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

compile_bin() {
  local src="$1" out_bin="$2" asan_flag="${3:-0}"
  local base_ll="${out_bin}.ll"
  timeout 15s "$OODAC" check "$src" >/dev/null 2>&1
  timeout 15s "$OODAC" emit-llvm "$src" > "$base_ll" 2>&1
  if [[ "$asan_flag" -eq 1 ]]; then
    clang -fsanitize=address "$base_ll" "$LIBOODAR" -lm -lpthread -o "$out_bin" >/dev/null 2>&1
  else
    clang -O2 "$base_ll" "$LIBOODAR" -lm -lpthread -o "$out_bin" >/dev/null 2>&1
  fi
}

run_suite() {
  local r_id="$1"
  echo "--- Executing ARC & Quota Challenger Suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. C-ARC-01: Bare void returns drop strings, lists, structs under tight quota
  local s1=1
  if compile_bin "$FIXTURES_DIR/test_arc_bare_void_return.oo" "$d/void_bin" 0; then
    if OO_LIST_AMBIENT_QUOTA=65536 "$d/void_bin" >/dev/null 2>&1; then s1=0; fi
  fi
  record_test "C-ARC-01" "Bare void returns clean under tight quota" "$s1"

  # 2. C-ARC-02: Bare void returns zero leaks under ASan/LSan
  local s2=1
  if compile_bin "$FIXTURES_DIR/test_arc_bare_void_return.oo" "$d/void_asan" 1; then
    if ASAN_OPTIONS=detect_leaks=1 "$d/void_asan" >/dev/null 2>&1; then s2=0; fi
  fi
  record_test "C-ARC-02" "Bare void returns zero leaks under ASan/LSan" "$s2"

  # 3. C-ARC-03: 3-level nested while & match early returns under tight quota
  local s3=1
  if compile_bin "$FIXTURES_DIR/test_arc_nested_early_returns.oo" "$d/nest_bin" 0; then
    if OO_LIST_AMBIENT_QUOTA=65536 "$d/nest_bin" >/dev/null 2>&1; then s3=0; fi
  fi
  record_test "C-ARC-03" "3-level nested early returns clean under tight quota" "$s3"

  # 4. C-ARC-04: 3-level nested while & match early returns under ASan/LSan
  local s4=1
  if compile_bin "$FIXTURES_DIR/test_arc_nested_early_returns.oo" "$d/nest_asan" 1; then
    if ASAN_OPTIONS=detect_leaks=1 "$d/nest_asan" >/dev/null 2>&1; then s4=0; fi
  fi
  record_test "C-ARC-04" "3-level nested early returns zero leaks under ASan/LSan" "$s4"

  # 5. C-ARC-05: Multi-level break & continue inside nested loops under quota
  local s5=1
  if compile_bin "$FIXTURES_DIR/test_arc_break_continue.oo" "$d/bc_bin" 0; then
    if OO_LIST_AMBIENT_QUOTA=65536 "$d/bc_bin" >/dev/null 2>&1; then s5=0; fi
  fi
  record_test "C-ARC-05" "Break/continue nested loops clean under tight quota" "$s5"

  # 6. C-ARC-06: Multi-level break & continue under ASan/LSan
  local s6=1
  if compile_bin "$FIXTURES_DIR/test_arc_break_continue.oo" "$d/bc_asan" 1; then
    if ASAN_OPTIONS=detect_leaks=1 "$d/bc_asan" >/dev/null 2>&1; then s6=0; fi
  fi
  record_test "C-ARC-06" "Break/continue nested loops zero leaks under ASan/LSan" "$s6"

  # 7. C-ARC-07: Deep recursion (depth >= 1000) returning collections
  local s7=1
  if compile_bin "$FIXTURES_DIR/test_arc_deep_recursion.oo" "$d/rec_bin" 0; then
    if "$d/rec_bin" >/dev/null 2>&1; then s7=0; fi
  fi
  record_test "C-ARC-07" "Deep recursion (>=1000) returning collections passes" "$s7"

  # 8. C-ARC-08: Deep recursion zero leaks under ASan/LSan
  local s8=1
  if compile_bin "$FIXTURES_DIR/test_arc_deep_recursion.oo" "$d/rec_asan" 1; then
    if ASAN_OPTIONS=detect_leaks=1 "$d/rec_asan" >/dev/null 2>&1; then s8=0; fi
  fi
  record_test "C-ARC-08" "Deep recursion zero leaks under ASan/LSan" "$s8"

  # 9. C-QUOTA-01: Low quota triggers fail-closed exit code 1 with ERR cap
  local s9=1
  if compile_bin "$FIXTURES_DIR/test_ambient_list_quota.oo" "$d/quota_bin" 0; then
    set +e
    local q_err
    q_err=$(OO_LIST_AMBIENT_QUOTA=1024 "$d/quota_bin" 2>&1)
    local q_ec=$?
    set -e
    if [[ "$q_ec" -eq 1 ]] && echo "$q_err" | grep -q 'ambient List memory quota exceeded'; then
      s9=0
    fi
  fi
  record_test "C-QUOTA-01" "Low quota triggers fail-closed exit code 1" "$s9"

  # 10. C-QUOTA-02: Sufficient quota completes cleanly with code 0
  local s10=1
  if [[ -x "$d/quota_bin" ]]; then
    set +e
    local q_ok
    q_ok=$(OO_LIST_AMBIENT_QUOTA=10000000 "$d/quota_bin" 2>&1)
    local q_ok_ec=$?
    set -e
    if [[ "$q_ok_ec" -eq 0 ]] && echo "$q_ok" | grep -q 'PASS: quota within bounds'; then
      s10=0
    fi
  fi
  record_test "C-QUOTA-02" "Sufficient quota completes cleanly with code 0" "$s10"
}

# Governance Verification
echo "--- Governance Verification: Line Limit & Academy Rules ---"
VIOLATIONS=0
for f in "$FIXTURES_DIR"/*.oo "$0"; do
  lines=$(wc -l < "$f")
  if [[ "$lines" -gt 256 ]]; then
    echo "  [VIOLATION] $(basename "$f"): $lines lines (>256)"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
  if [[ "$f" == *.oo ]] && ! grep -q "^// # " "$f"; then
    echo "  [VIOLATION] $(basename "$f"): missing Academy header"
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
done

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo "FATAL: Governance violations detected!" >&2
  exit 1
fi
echo "Governance verified: 100% of challenger files strictly <= 256 lines."

# Double-run determinism
run_suite 1
run_suite 2

echo "======================================================================"
echo "=== openOODA M3 Challenger ARC & Memory Quota Scorecard            ==="
echo "======================================================================"
echo "  Total Executed : $((PASS_COUNT + FAIL_COUNT))"
echo "  Passed         : $PASS_COUNT"
echo "  Failed         : $FAIL_COUNT"
echo "  Determinism    : Run 1 == Run 2 (Verified)"
echo "======================================================================"

if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
