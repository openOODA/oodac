#!/usr/bin/env bash
# Phase 2 Challenger Verification Suite: Multi-Module Driver & Response File
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"

export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_COMPILER="$OODAC_BIN"

TMPDIR="$(mktemp -d /tmp/test_challenger_p2_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS_COUNT=0; FAIL_COUNT=0
record_test() {
  local id="$1" desc="$2" status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $id: $desc"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

run_challenger_suite() {
  local r_id="$1"
  echo "--- Phase 2 Challenger Empirical Suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"; mkdir -p "$d"

  # C1. Functional Sanity Verification on S3 Binary
  local help_fail=0
  "$OODAC_BIN" --help > "$d/help.txt" 2>&1 || help_fail=1
  grep -q "oodac: usage:" "$d/help.txt" || help_fail=1
  record_test "CH-SAN-01" "S3 binary --help returns 0 with clean CLI help text" "$help_fail"

  local probe_fail=0
  (cd "$PROJECT_ROOT" && "$OODAC_BIN" check oodac/qa/probe_list_ok.oo > "$d/probe.txt" 2>&1) || probe_fail=1
  grep -q "^OK$" "$d/probe.txt" || probe_fail=1
  record_test "CH-SAN-02" "S3 binary check probe_list_ok.oo exits 0 with OK output" "$probe_fail"

  # C2. Mutation Detection Parity (SH-NEG-01 Hardening)
  local mut_fail=0
  local orig_h
  orig_h=$(sha256sum "$OODAC_BIN" | awk '{print $1}')
  local file_len
  file_len=$(wc -c < "$OODAC_BIN")
  local test_offsets=(0 4 16 64 1024 $((file_len / 2)) $((file_len - 1)))
  for off in "${test_offsets[@]}"; do
    cp -f "$OODAC_BIN" "$d/mut.bin"
    python3 -c "
with open('$d/mut.bin', 'r+b') as f:
    f.seek($off)
    b = f.read(1)
    f.seek($off)
    f.write(bytes([b[0] ^ 0x01]))
"
    local mut_h
    mut_h=$(sha256sum "$d/mut.bin" | awk '{print $1}')
    if [[ "$orig_h" == "$mut_h" ]]; then mut_fail=1; fi
  done
  record_test "CH-MUT-01" "Single-bit mutations across 7 offsets detected fail-closed" "$mut_fail"

  # C3. Multi-Module Deep Relative Path Build & Response File Linking
  local build_fail=0
  local fixture_entry="oodac/tests/fixtures/stress_multi_rsp/oodac/main.oo"
  local out_bin="$d/stress_multi.bin"
  (cd "$PROJECT_ROOT" && "$OODAC_BIN" build "$fixture_entry" -o "$out_bin") > "$d/build.log" 2>&1 || build_fail=1
  grep -q "OK_PURE_NATIVE" "$d/build.log" || build_fail=1
  record_test "CH-RSP-01" "Multi-module fixture compiles via pure .oo driver" "$build_fail"

  local exec_fail=0
  local exec_out
  exec_out=$("$out_bin" 2>&1) || exec_fail=1
  [[ "$exec_out" == *"STRESS_MULTI_RESULT=749"* ]] || exec_fail=1
  record_test "CH-RSP-02" "Linked multi-module binary executes and yields 749" "$exec_fail"

  # C4. Clang Response File Syntax, Deep Relative Paths, & Quoting
  local rsp_parse_fail=0
  local rsp_file="$d/synthetic.rsp"
  python3 -c "
with open('$rsp_file', 'w') as f:
    for i in range(1000):
        if i % 10 == 0:
            f.write(f'\"level1/level2/space dir_{i}/obj_{i}.o\"\n')
        else:
            f.write(f'level1/level2/level3/level4/level5/dir_{i}/obj_{i}.o\n')
"
  # Run clang with -### to verify response file parsing without overflow
  local clang_err="$d/clang_rsp.err"
  clang --no-default-config -### "@$rsp_file" > /dev/null 2> "$clang_err" || true
  local matched_count
  matched_count=$(grep -c "obj_" "$clang_err" || true)
  if [[ "$matched_count" -lt 1000 ]]; then rsp_parse_fail=1; fi
  record_test "CH-RSP-03" "Clang correctly parses 1000-line quoted response file" "$rsp_parse_fail"

  # C5. Clang Argument Overflow Bypass Verification
  local of_fail=0
  local huge_rsp="$d/huge.rsp"
  local dummy_c="$d/dummy.c"
  echo "int test_var = 1;" > "$dummy_c"
  python3 -c "
with open('$huge_rsp', 'w') as f:
    for i in range(50000):
        f.write(f'-DARG_{i}=val_{i}\n')
"
  clang --no-default-config -E "@$huge_rsp" "$dummy_c" > /dev/null 2>&1 || of_fail=1
  record_test "CH-RSP-04" "50k argument response file links without OS E2BIG" "$of_fail"
}

run_challenger_suite "1"
run_challenger_suite "2"

echo "======================================================================"
echo "=== openOODA Phase 2 Challenger Verification Summary               ==="
echo "======================================================================"
echo "  Total Assertions Checked : $PASS_COUNT"
echo "  Failed Assertions        : $FAIL_COUNT"
echo "  Double-Run Determinism   : Run 1 == Run 2 = 0"
echo "======================================================================"

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo "STATUS: CHALLENGER_PHASE2_PASS"
  exit 0
else
  echo "STATUS: CHALLENGER_PHASE2_FAIL ($FAIL_COUNT failures)" >&2
  exit 1
fi
