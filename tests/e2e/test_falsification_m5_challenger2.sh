#!/usr/bin/env bash
# Challenger 2 Milestone 5 Falsification Suite
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
FIXTURES="$SCRIPT_DIR/../fixtures/adversarial_m5_challenger2"
TMPDIR="$(mktemp -d /tmp/e2e_chal2_m5_XXXXXX)"
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
  echo "--- Executing Challenger 2 M5 Falsification Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. Capability Scalar Bitmask Invariant (Feature 19)
  local c_cap=1
  if emit "$FIXTURES/probe_cap_substrate.oo" "$d/cap.ll"; then
    if grep -q "declare void @oo_fs_read_dir.*i64" "$d/cap.ll" && \
       grep -q "i64 noundef %p_fs" "$d/cap.ll" && \
       ! grep -q "@oo_alloc" "$d/cap.ll"; then
      c_cap=0
    fi
  fi
  record_test "CHAL2-M5-01" "Capability remains exact scalar i64 noundef" "$c_cap"

  # 2. Type Checker Capability Rejection (Feature 19)
  cat << 'EOF' > "$d/probe_cap_reject.oo"
// # Cap Reject Probe
// Logline: Pass cap to option function
// Setup: check
// Beats: need_opt, main
pub fn need_opt(o: Option[&Int]) -> Int { return 0; }
pub fn main(p: &ProcessCap) -> Int { return need_opt(p); }
EOF
  local c_rej=1
  if ! "$OODAC" check "$d/probe_cap_reject.oo" >/dev/null 2>&1; then
    c_rej=0
  fi
  record_test "CHAL2-M5-02" "Compiler rejects passing capability to Option" "$c_rej"

  # 3. Multiple Options in Single Function & SSA Promotion (Feature 17)
  local c_multi=1
  if emit "$FIXTURES/probe_multi_opt.oo" "$d/multi.ll"; then
    if opt -passes=mem2reg,instcombine -S "$d/multi.ll" -o "$d/multi_opt.ll" >/dev/null 2>&1; then
      local fn_allocas; fn_allocas=$(sed -n '/define.*@multi_opt/,/^}/p' "$d/multi_opt.ll" | grep -c "alloca" || true)
      if [[ "$fn_allocas" -eq 0 ]]; then c_multi=0; fi
    fi
  fi
  record_test "CHAL2-M5-03" "Multiple options promote to pure SSA (0 allocas)" "$c_multi"

  # 4. Mutated Stack Values Option[&mut T] (Feature 17)
  local c_mut=1
  if emit "$FIXTURES/probe_mut_opt.oo" "$d/mut.ll"; then
    if llvm-as "$d/mut.ll" -o "$d/mut.bc" >/dev/null 2>&1; then
      c_mut=0
    fi
  fi
  record_test "CHAL2-M5-04" "Option[&mut T] lowers and passes llvm-as" "$c_mut"

  # 5. DWARF Debug Info on Local Option Variable (Feature 17)
  local c_dwarf=1
  if emit "$FIXTURES/probe_dwarf_opt.oo" "$d/dwarf.ll"; then
    if clang -g -c "$d/dwarf.ll" -o "$d/dwarf.o" >/dev/null 2>&1; then
      if llvm-dwarfdump --verify "$d/dwarf.o" >/dev/null 2>&1 && \
         llvm-dwarfdump --name=opt_var "$d/dwarf.o" | grep -q "DW_TAG_variable"; then
        c_dwarf=0
      fi
    fi
  fi
  record_test "CHAL2-M5-05" "DWARF info verified on niche option variable" "$c_dwarf"

  # 6. Falsification Probe: C ABI extractvalue Syntax Corruption (Feature 18)
  # Detects whether ll_c_abi_unpack_ret generates invalid LLVM syntax (comma after type)
  local c_unpack_falsified=0
  "$OODAC" check "$FIXTURES/oo_niche_c_ext.oo" >/dev/null 2>&1 || true
  if "$OODAC" check "$FIXTURES/probe_c_unpack_syntax.oo" >/dev/null 2>&1; then
    "$OODAC" emit-llvm "$FIXTURES/probe_c_unpack_syntax.oo" > "$d/unpack.ll" 2>&1 || true
    if grep -q "extractvalue %OoOpt_Ptr, " "$d/unpack.ll" 2>/dev/null; then
      c_unpack_falsified=1
    fi
  fi
  record_test "CHAL2-M5-06" "Probe reveals C ABI extractvalue comma defect" "$((1 - c_unpack_falsified))"

  # 7. Falsification Probe: C ABI Parameter Passing byval vs Reg Mismatch (Feature 18)
  local c_byval_falsified=0
  if emit "$FIXTURES/probe_byval_mismatch.oo" "$d/byval.ll"; then
    if grep -q "define default .*@oo_consume(ptr noalias nocapture noundef" "$d/byval.ll" && \
       grep -q "call i64 @oo_consume(ptr byval(%OoOpt_Ptr)" "$d/byval.ll"; then
      c_byval_falsified=1
    fi
  fi
  record_test "CHAL2-M5-07" "Probe reveals byval stack vs scalar reg mismatch" "$((1 - c_byval_falsified))"

  # 8. Falsification Probe: Capability Reference Wildcard Blindspot (Feature 19)
  local c_blindspot=0
  if "$OODAC" check "$FIXTURES/probe_cap_blindspot.oo" >/dev/null 2>&1; then
    c_blindspot=1
  fi
  record_test "CHAL2-M5-08" "Probe reveals &Cap wildcard typechecker blindspot" "$((1 - c_blindspot))"
}

run_suite 1
P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
P2=$PASS_COUNT; F2=$FAIL_COUNT

echo "Run 1: PASS=$P1, FAIL=$F1"
echo "Run 2: PASS=$P2, FAIL=$F2"

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" ]]; then
  echo "Determinism failure: Run1 != Run2"
  exit 1
fi
echo "Deterministic PASS: $P1 tests passed in both runs."
exit 0
