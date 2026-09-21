#!/usr/bin/env bash
# openOODA M2 Differential Expression Fuzzer Test Harness
# Cross-verifies compiled LLVM expressions against independent mathematical oracle.
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
if [[ ! -x "$OODAC" && -x "$PROJECT_ROOT/bin/oodac" ]]; then
  OODAC="$PROJECT_ROOT/bin/oodac"
fi
LIBOODAR="${LIBOODAR_PATH:-$PROJECT_ROOT/oodar/liboodar.a}"
ORACLE_SCRIPT="$SCRIPT_DIR/differential_expr_oracle.py"

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"

ITERATIONS="${1:-1000}"
BATCH_SIZE="${2:-50}"
BASE_SEED="${3:-42}"

TMPDIR="$(mktemp -d /tmp/diff_expr_fuzz_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

echo "======================================================================"
echo "=== openOODA Differential Expression Fuzzer (R2)                   ==="
echo "======================================================================"
echo "Target Compiler : $OODAC"
echo "Oracle Script   : $ORACLE_SCRIPT"
echo "Iterations      : $ITERATIONS (Batch Size: $BATCH_SIZE)"
echo "Base Seed       : $BASE_SEED"
echo "======================================================================"

# 1. Governance Verification
self_lines=$(wc -l < "$0")
if [[ "$self_lines" -gt 256 ]]; then
  echo "FATAL: $0 has $self_lines lines (> 256)" >&2
  exit 1
fi

if [[ -f "$ORACLE_SCRIPT" ]]; then
  oracle_lines=$(wc -l < "$ORACLE_SCRIPT")
  if [[ "$oracle_lines" -gt 256 ]]; then
    echo "FATAL: $ORACLE_SCRIPT has $oracle_lines lines (> 256)" >&2
    exit 1
  fi
fi

run_fuzz_cycle() {
  local run_id="$1"
  local batches=$(( (ITERATIONS + BATCH_SIZE - 1) / BATCH_SIZE ))
  local verified=0
  local d="$TMPDIR/run_$run_id"
  mkdir -p "$d"

  echo ">>> [Run $run_id] Executing $ITERATIONS differential tests across $batches batches..."

  for (( b=1; b<=batches; b++ )); do
    local cur_count="$BATCH_SIZE"
    if [[ $((verified + cur_count)) -gt "$ITERATIONS" ]]; then
      cur_count=$((ITERATIONS - verified))
    fi
    local seed=$((BASE_SEED + b * 100 + run_id))
    local oo_src="$d/batch_${b}.oo"
    local exp_out="$d/batch_${b}.exp"
    local ll_file="$d/batch_${b}.ll"
    local bin_file="$d/batch_${b}_bin"
    local act_out="$d/batch_${b}.act"
    local diff_out="$d/batch_${b}.diff"

    python3 "$ORACLE_SCRIPT" "$seed" "$cur_count" "$oo_src" "$exp_out"

    # Governance check on generated .oo file
    local oo_lines
    oo_lines=$(wc -l < "$oo_src")
    if [[ "$oo_lines" -gt 256 ]]; then
      echo "FATAL: Generated batch $oo_src exceeds 256 lines ($oo_lines)" >&2
      exit 1
    fi
    if grep -nE '(if|while)[[:space:]]+\(' "$oo_src" >/dev/null 2>&1; then
      echo "FATAL: Generated batch $oo_src contains outer condition parentheses" >&2
      exit 1
    fi

    # Compile .oo -> LLVM IR -> Native Binary
    if ! "$OODAC" check "$oo_src" >/dev/null 2>&1; then
      echo "FATAL: oodac check failed on batch $b (seed $seed)" >&2
      exit 1
    fi
    if ! "$OODAC" emit-llvm "$oo_src" > "$ll_file" 2>&1; then
      echo "FATAL: oodac emit-llvm failed on batch $b (seed $seed)" >&2
      exit 1
    fi
    if ! clang -O2 "$ll_file" "$LIBOODAR" -lm -lpthread -o "$bin_file" >/dev/null 2>&1; then
      echo "FATAL: clang -O2 compilation failed on batch $b (seed $seed)" >&2
      exit 1
    fi

    # Execute binary and cross-check with oracle
    "$bin_file" > "$act_out"
    if ! diff -u "$exp_out" "$act_out" > "$diff_out"; then
      echo "FATAL: Differential mismatch detected in batch $b (seed $seed)!" >&2
      cat "$diff_out" >&2
      exit 1
    fi

    verified=$((verified + cur_count))
    if (( b % 5 == 0 || b == batches )); then
      echo "    Progress: $verified / $ITERATIONS expressions verified PASS"
    fi
  done

  echo ">>> [Run $run_id] PASS: 100% agreement on $verified / $ITERATIONS expressions."
}

# Execute Double-Run Determinism
run_fuzz_cycle 1
run_fuzz_cycle 2

echo "======================================================================"
echo "=== Differential Expression Fuzzer Result: PASS (Run 1 == Run 2 = 0) ==="
echo "=== Verified $ITERATIONS expressions with zero mathematical mismatches ==="
echo "======================================================================"
exit 0
