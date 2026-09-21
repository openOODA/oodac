#!/usr/bin/env bash
# Challenger 1 M2 Stress Runner: Grammar Mutation & Differential Math Stress
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
if [[ ! -x "$OODAC" && -x "$PROJECT_ROOT/bin/oodac" ]]; then
  OODAC="$PROJECT_ROOT/bin/oodac"
fi

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export CHALLENGER_DIFF_BATCHES="${CHALLENGER_DIFF_BATCHES:-10}"

echo "=== M2 Challenger 1: Grammar & Expression Stress Runner ==="

# 1. Line count governance check
for f in "$SCRIPT_DIR/test_challenger_m2_stress.py" "$0"; do
  lines=$(wc -l < "$f")
  if [[ "$lines" -gt 256 ]]; then
    echo "ERR: $f exceeds 256 LOC ($lines)" >&2
    exit 1
  fi
done

# 2. Execute under double-run determinism
run_stress() {
  local rid="$1"
  echo ">>> [Run $rid] Executing Challenger 1 Stress Suite..."
  python3 "$SCRIPT_DIR/test_challenger_m2_stress.py"
  echo ">>> [Run $rid] PASS"
}

run_stress 1
run_stress 2

echo "=== All Challenger 1 Stress Tests PASSED (Run 1 == Run 2 = 0) ==="
exit 0
