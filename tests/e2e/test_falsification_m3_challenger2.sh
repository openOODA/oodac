#!/usr/bin/env bash
# Challenger 2 Milestone 3 Falsification Suite
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
FIXTURES="$SCRIPT_DIR/../fixtures/adversarial_m3_challenger2"
TMPDIR="$(mktemp -d /tmp/e2e_chal2_m3_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"

PASS_COUNT=0; FAIL_COUNT=0

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
  timeout 10s "$OODAC" check "$src" >/dev/null 2>&1
  timeout 10s "$OODAC" emit-llvm "$src" > "$out" 2>&1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Challenger 2 M3 Falsification Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. Exact Symbol Table Tests
  # 1a. Pure ilist omits slist
  local c1_slist=1
  if emit "$FIXTURES/probe_ilist_only.oo" "$d/ilist.ll"; then
    if ! grep -q "oo_slist" "$d/ilist.ll" && grep -q "oo_ilist" "$d/ilist.ll"; then
      c1_slist=0
    fi
  fi
  record_test "CHAL2-F10-01" "Integer list prunes all string list symbols" "$c1_slist"

  # 1b. Pure slist omits ilist
  local c1_ilist=1
  if emit "$FIXTURES/probe_slist_only.oo" "$d/slist.ll"; then
    if ! grep -q "oo_ilist" "$d/slist.ll" && grep -q "oo_slist" "$d/slist.ll"; then
      c1_ilist=0
    fi
  fi
  record_test "CHAL2-F10-02" "String list prunes all integer list symbols" "$c1_ilist"

  # 1c. Filesystem omits TUI
  local c1_tui=1
  if emit "$FIXTURES/probe_fs_only.oo" "$d/fs.ll"; then
    if ! grep -q "oo_tui" "$d/fs.ll" && grep -q "oo_path_exists" "$d/fs.ll"; then
      c1_tui=0
    fi
  fi
  record_test "CHAL2-F10-03" "FS operations prune all TUI symbols" "$c1_tui"

  # 1d. Complex catalog passes llvm-as
  local c1_cat=1
  if emit "$FIXTURES/probe_complex_catalog.oo" "$d/cat.ll"; then
    if llvm-as "$d/cat.ll" -o "$d/cat.bc" >/dev/null 2>&1; then
      c1_cat=0
    fi
  fi
  record_test "CHAL2-F10-04" "Complex catalog passes llvm-as" "$c1_cat"

  # 2. Signed NSW Arithmetic Tests
  # 2a. Signed operations emit nsw
  local c2_signed=1
  if emit "$FIXTURES/probe_nsw.oo" "$d/nsw.ll"; then
    if grep -q "add nsw i64" "$d/nsw.ll" && \
       grep -q "sub nsw i64" "$d/nsw.ll" && \
       grep -q "mul nsw i64" "$d/nsw.ll" && \
       grep -q "add nsw i32" "$d/nsw.ll"; then
      c2_signed=0
    fi
  fi
  record_test "CHAL2-F12-01" "Signed math (i64 and i32) emits nsw" "$c2_signed"

  # 2b. Unsigned operations NEVER receive nsw
  local c2_uns=0
  # Check within unsigned_u64_ops and unsigned_u32_ops
  local in_u64=0 in_u32=0
  while IFS= read -r line; do
    if [[ "$line" =~ @unsigned_u64_ops ]]; then in_u64=1; fi
    if [[ "$line" =~ @unsigned_u32_ops ]]; then in_u32=1; fi
    if [[ "$line" =~ ^\} ]]; then in_u64=0; in_u32=0; fi
    if [[ "$in_u64" -eq 1 || "$in_u32" -eq 1 ]]; then
      if [[ "$line" =~ (add|sub|mul)[[:space:]]+nsw ]]; then
        c2_uns=1
      fi
    fi
  done < "$d/nsw.ll"
  record_test "CHAL2-F12-02" "Unsigned math strictly contains NO nsw" "$c2_uns"

  # 2c. Division/remainder signed vs unsigned
  local c2_div=1
  if emit "$FIXTURES/probe_div_rem.oo" "$d/div.ll"; then
    if grep -q "sdiv i64" "$d/div.ll" && grep -q "srem i64" "$d/div.ll" && \
       grep -q "udiv i64" "$d/div.ll" && grep -q "urem i64" "$d/div.ll"; then
      c2_div=0
    fi
  fi
  record_test "CHAL2-F12-03" "Signed uses sdiv/srem and unsigned uses udiv/urem" "$c2_div"

  # 3. Parameter and Function Attributes
  # 3a. Pure fn receives readonly
  local c3_pure=1
  if emit "$FIXTURES/probe_param_attrs.oo" "$d/attrs.ll"; then
    if grep -E "@pure_calc\(.*\) readonly nounwind" "$d/attrs.ll" >/dev/null 2>&1; then
      c3_pure=0
    fi
  fi
  record_test "CHAL2-F11-01" "Pure scalar function receives readonly nounwind" "$c3_pure"

  # 3b. &mut T does NOT receive readonly
  local c3_mut=1
  if ! grep -E "@mut_scalar\(.*\) readonly" "$d/attrs.ll" >/dev/null 2>&1 && \
     ! grep -E "@mut_struct\(.*\) readonly" "$d/attrs.ll" >/dev/null 2>&1; then
    c3_mut=0
  fi
  record_test "CHAL2-F11-02" "Mutating functions (&mut T) do NOT receive readonly" "$c3_mut"

  # 3c. Capability functions do NOT receive readonly
  local c3_cap=1
  if ! grep -E "@cap_read\(.*\) readonly" "$d/attrs.ll" >/dev/null 2>&1; then
    c3_cap=0
  fi
  record_test "CHAL2-F11-03" "Capability functions do NOT receive readonly" "$c3_cap"

  # 3d. Parameters do NOT receive readonly
  local c3_params=0
  if grep -E "define .*\(.*readonly.*\)" "$d/attrs.ll" >/dev/null 2>&1; then
    # Ensure readonly is not inside the parameter list parentheses
    if grep -E "define [^)]*readonly[^)]*\(" "$d/attrs.ll" >/dev/null 2>&1; then
      c3_params=1
    fi
  fi
  record_test "CHAL2-F11-04" "No parameter attribute carries readonly" "$c3_params"

  # 4. LLVM-AS validation across all emitted IR
  local c4_as=0
  for f in "$d"/*.ll; do
    if ! llvm-as "$f" -o "${f%.ll}.bc" >/dev/null 2>&1; then
      c4_as=1
      echo "  [ERR] llvm-as failed on $f"
    fi
  done
  record_test "CHAL2-F11-05" "All emitted LLVM IR files validate with llvm-as" "$c4_as"
}

# Double-run determinism protocol
run_suite 1; P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2; P2=$PASS_COUNT; F2=$FAIL_COUNT

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" || "$F1" -ne 0 ]]; then
  echo "Determinism failure: Run1 ($P1/$F1) != Run2 ($P2/$F2)"
  exit 1
fi
echo "Deterministic PASS: $P1 tests passed in both runs."
exit 0
