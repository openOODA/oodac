#!/usr/bin/env bash
# Challenger 2 Adversarial Test Runner: SMT DBM & Oracle Soundness
# Verifies DBM edge-case graphs, math oracle two's complement, and determinism.
# Compliance: wc -l <= 256.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
if [[ ! -x "$OODAC" && -x "$PROJECT_ROOT/bin/oodac" ]]; then
  OODAC="$PROJECT_ROOT/bin/oodac"
fi
LIBOODAR="${LIBOODAR_PATH:-$PROJECT_ROOT/oodar/liboodar.a}"

TMPDIR="$(mktemp -d /tmp/challenger_m2_runner_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

echo "=== M2 Challenger 2: Adversarial Stress Runner ==="

# 1. Governance check
for f in "$SCRIPT_DIR/test_adversarial_dbm_challenger.oo" \
         "$SCRIPT_DIR/test_adversarial_oracle_challenger.py" \
         "$0"; do
  lines=$(wc -l < "$f")
  if [[ "$lines" -gt 256 ]]; then
    echo "ERR: $f exceeds 256 LOC ($lines)" >&2
    exit 1
  fi
done

# 2. DBM Adversarial Stress Test (Run 1 & Run 2)
echo ">>> [Stage 1] Compiling and running DBM Adversarial Stress Test..."
dbm_bin="$TMPDIR/challenger_dbm.bin"
"$OODAC" build "$SCRIPT_DIR/test_adversarial_dbm_challenger.oo" -o "$dbm_bin" >/dev/null
out1=$("$dbm_bin")
if [[ "$out1" != *"CHALLENGER_DBM_PASS"* ]]; then
  echo "ERR: DBM challenger run 1 failed: $out1" >&2
  exit 1
fi
out2=$("$dbm_bin")
if [[ "$out1" != "$out2" ]]; then
  echo "ERR: DBM challenger non-deterministic" >&2
  exit 1
fi
echo "    Stage 1 PASS: DBM boundary refutations & soundness verified."

# 3. Differential Expression Oracle Adversarial Units
echo ">>> [Stage 2] Running Oracle Adversarial Unit Checks..."
python3 "$SCRIPT_DIR/test_adversarial_oracle_challenger.py"
echo "    Stage 2 PASS: INT64_MIN, shifts, short-circuiting verified."

# 4. End-to-End Extended Differential Expression Cross-Validation
echo ">>> [Stage 3] Cross-verifying 1,000 differential expressions against LLVM binary..."
bash "$SCRIPT_DIR/test_differential_expr_fuzzer.sh" 1000 50 999
echo "    Stage 3 PASS: 100% mathematical parity across 1,000 expressions."

echo "=== All Challenger 2 Empirical Tests PASSED (Run 1 == Run 2 = 0) ==="
exit 0
