#!/usr/bin/env bash
# Test Suite: SMT Boundary Refutation Fuzzer & Soundness Oracle
# Strictly adheres to wc -l <= 256, Academy Laws, Double-Run Determinism.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC_BIN="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
if [[ ! -x "$OODAC_BIN" && -x "$PROJECT_ROOT/bin/oodac" ]]; then
  OODAC_BIN="$PROJECT_ROOT/bin/oodac"
fi

TMPDIR="$(mktemp -d /tmp/test_smt_fuzz_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

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

echo "=== SMT Boundary Refutation Fuzzing Suite ==="

# 1. Academy Governance & Line Count Checks
gov_fail=0
fuzz_oo="$PROJECT_ROOT/oodac/tests/fuzz/smt_boundary_fuzzer.oo"
fuzz_sh="$PROJECT_ROOT/oodac/tests/fuzz/test_smt_boundary_fuzzer.sh"

for f in "$fuzz_oo" "$fuzz_sh"; do
  if [[ -f "$f" ]]; then
    loc=$(wc -l < "$f")
    if [[ "$loc" -gt 256 ]]; then
      echo "ERR: $f exceeds 256 LOC ceiling ($loc lines)"
      gov_fail=1
    fi
  else
    echo "ERR: missing expected suite file $f"
    gov_fail=1
  fi
done

if [[ -f "$fuzz_oo" ]]; then
  if ! grep -q "^// # " "$fuzz_oo" || \
     ! grep -q "^// Logline:" "$fuzz_oo" || \
     ! grep -q "^// Setup:" "$fuzz_oo" || \
     ! grep -q "^// Beats:" "$fuzz_oo"; then
    echo "ERR: missing 4-element Academy header in $fuzz_oo"
    gov_fail=1
  fi
  if grep -q "if (" "$fuzz_oo" || grep -q "while (" "$fuzz_oo"; then
    echo "ERR: outer parentheses detected in condition expressions"
    gov_fail=1
  fi
fi
record_test "SMT-GOV-01" "Academy laws, <=256 LOC, 4-element header" "$gov_fail"

# 2. Multi-Module Compilation of Fuzzer Harness
build_fail=0
fuzzer_bin="$TMPDIR/smt_boundary_fuzzer.bin"
build_out=$(OODAC_BIN="$OODAC_BIN" "$OODAC_BIN" build "$fuzz_oo" -o "$fuzzer_bin" 2>&1 || true)
if [[ ! -x "$fuzzer_bin" ]]; then
  echo "ERR: compilation of smt_boundary_fuzzer.oo failed: $build_out"
  build_fail=1
fi
record_test "SMT-BLD-01" "Multi-module compilation of fuzzer harness" "$build_fail"

# 3. Execution & Soundness Verification (Run 1: >=1,000 iterations)
run1_fail=0
run1_out=$("$fuzzer_bin" 2>&1 || true)
if ! echo "$run1_out" | grep -q "SMT_FUZZER_PASS"; then
  echo "ERR: fuzzer harness failed execution: $run1_out"
  run1_fail=1
fi
if ! echo "$run1_out" | grep -q "false_positives=0"; then
  echo "ERR: false positives detected: $run1_out"
  run1_fail=1
fi
record_test "SMT-SND-01" "In-process fuzzer >=1,000 iters (0 false positives)" "$run1_fail"

# 4. Double-Run Determinism (Run 1 == Run 2 = 0)
run2_fail=0
run2_out=$("$fuzzer_bin" 2>&1 || true)
if [[ "$run1_out" != "$run2_out" ]]; then
  echo "ERR: non-deterministic execution between Run 1 and Run 2"
  run2_fail=1
fi
record_test "SMT-DET-01" "Double-run determinism (Run 1 == Run 2 = 0)" "$run2_fail"

# 5. Compiler CLI Fail-Closed End-to-End Contract Verification
cli_fail=0
cat << 'EOF' > "$TMPDIR/fixture_bad_contract.oo"
// # Bad Contract Fixture
// Logline: Invalid postcondition refuted by SMT
// Setup: Pure compute
// Beats: B
pub fn bad_math(x: Int) -> Int
requires x >= 0
ensures result > x
spec "Contradictory on x=0"
{
    return x;
}
EOF

cli_out=$("$OODAC_BIN" check "$TMPDIR/fixture_bad_contract.oo" 2>&1 || true)
if ! echo "$cli_out" | grep -q "ERR" || ! echo "$cli_out" | grep -q "x = 0"; then
  echo "ERR: compiler check failed to refute bad contract fail-closed: $cli_out"
  cli_fail=1
fi
record_test "SMT-CLI-01" "Compiler check surfaces refutation fail-closed" "$cli_fail"

echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed."
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
