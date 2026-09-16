#!/usr/bin/env bash
# # Adversarial Test Suite for M1 Sovereign LLVM Backend
#
# Logline: Stress-test oodac on call strings, control flow, and debug info.
#
# Setup: Tests adversarial inputs and checks llvm-as / clang -c diagnostics.
#
# Beats:
#   1. Test string literals with call patterns.
#   2. Test complex control flow.
#   3. Test multi-line expressions and leading operators.
#   4. Validate struct retain/release debug info.
#   5. Audit corpus files for invalid debug info warnings.

set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="$(mktemp -d /tmp/adv_m1_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OODA_COMPILER="$OODAC"
export OODAC_BIN="$OODAC"
export OODA_NO_JAIL=1
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-8589934592}"

fails=0

echo "=== M1 Adversarial Stress Test Suite ==="

# Test 1: Call strings
echo "--- 1. Testing call string patterns ---"
"$OODAC" check "$ROOT/tests/fixtures/adversarial_call_strings.oo"
"$OODAC" emit-llvm "$ROOT/tests/fixtures/adversarial_call_strings.oo" \
  > "$TMPDIR/call.ll"
llvm-as "$TMPDIR/call.ll" -o "$TMPDIR/call.bc"
"$OODAC" build "$ROOT/tests/fixtures/adversarial_call_strings.oo" \
  -o "$TMPDIR/call.bin"
"$TMPDIR/call.bin" > "$TMPDIR/call.out"
grep -q 'foo = call bar' "$TMPDIR/call.out"
echo "  [PASS] Call strings emit and execute cleanly"

# Test 2: Control flow
echo "--- 2. Testing complex control flow ---"
"$OODAC" check "$ROOT/tests/fixtures/adversarial_control_flow.oo"
"$OODAC" emit-llvm "$ROOT/tests/fixtures/adversarial_control_flow.oo" \
  > "$TMPDIR/cf.ll"
llvm-as "$TMPDIR/cf.ll" -o "$TMPDIR/cf.bc"
"$OODAC" build "$ROOT/tests/fixtures/adversarial_control_flow.oo" \
  -o "$TMPDIR/cf.bin"
"$TMPDIR/cf.bin" > "$TMPDIR/cf.out"
grep -q '538' "$TMPDIR/cf.out"
grep -q '40' "$TMPDIR/cf.out"
echo "  [PASS] Complex control flow executes with exact parity"

# Test 3: Multi-line expressions
echo "--- 3. Testing multi-line expressions ---"
"$OODAC" check "$ROOT/tests/fixtures/adversarial_multiline.oo"
"$OODAC" emit-llvm "$ROOT/tests/fixtures/adversarial_multiline.oo" \
  > "$TMPDIR/ml.ll"
llvm-as "$TMPDIR/ml.ll" -o "$TMPDIR/ml.bc"
"$OODAC" build "$ROOT/tests/fixtures/adversarial_multiline.oo" \
  -o "$TMPDIR/ml.bin"
"$TMPDIR/ml.bin" > "$TMPDIR/ml.out"
grep -q '1075' "$TMPDIR/ml.out"
echo "  [PASS] Multi-line expressions execute with exact parity"

# Test 3b: Multi-line leading operators
echo "--- 3b. Testing multi-line leading operators ---"
"$OODAC" check "$ROOT/tests/fixtures/adversarial_multiline_leading_op.oo"
"$OODAC" build "$ROOT/tests/fixtures/adversarial_multiline_leading_op.oo" \
  -o "$TMPDIR/ml_op.bin"
"$TMPDIR/ml_op.bin" > "$TMPDIR/ml_op.out"
grep -q '65' "$TMPDIR/ml_op.out"
grep -q '1' "$TMPDIR/ml_op.out"
echo "  [PASS] Multi-line leading operators execute cleanly"

# Test 4: Struct with call string & debug info validation
echo "--- 4. Testing struct retain/release debug info ---"
"$OODAC" check "$ROOT/tests/fixtures/adversarial_struct_call_strings.oo" >/dev/null
"$OODAC" emit-llvm \
  "$ROOT/tests/fixtures/adversarial_struct_call_strings.oo" \
  > "$TMPDIR/st_call.ll"
llvm_as_msg=$(llvm-as "$TMPDIR/st_call.ll" -o "$TMPDIR/st_call.bc" 2>&1 || true)
clang_msg=$(clang --no-default-config --target=x86_64-unknown-linux-gnu -c "$TMPDIR/st_call.ll" -o "$TMPDIR/st_call.o" 2>&1 || true)
if echo "$llvm_as_msg $clang_msg" | grep -q "ignoring invalid debug info"; then
  echo "  [FAIL] struct retain/release triggers invalid debug info:"
  echo "         $llvm_as_msg $clang_msg"
  fails=$((fails + 1))
else
  echo "  [PASS] struct retain/release has valid debug info"
fi

# Test 5: Corpus audit
echo "--- 5. Auditing corpus for invalid debug info ---"
corpus_warns=0
for f in "$ROOT/bootstrap/corpus/emit-llvm/pass"/*.oo; do
  bn=$(basename "$f")
  "$OODAC" check "$f" >/dev/null 2>&1 || continue
  "$OODAC" emit-llvm "$f" > "$TMPDIR/$bn.ll" 2>/dev/null || continue
  warn_as=$(llvm-as "$TMPDIR/$bn.ll" -o "$TMPDIR/$bn.bc" 2>&1 || true)
  warn_cl=$(clang --no-default-config -c "$TMPDIR/$bn.ll" -o "$TMPDIR/$bn.o" 2>&1 | grep -i "invalid debug" || true)
  if echo "$warn_as $warn_cl" | grep -q "ignoring invalid debug info"; then
    echo "  [WARN] $bn: invalid debug info"
    corpus_warns=$((corpus_warns + 1))
  fi
done
echo "Total corpus files with invalid debug info: $corpus_warns"
if [[ "$corpus_warns" -gt 0 ]]; then
  fails=$((fails + corpus_warns))
fi

echo "=== Adversarial Suite Finished: $fails failures ==="
test "$fails" -eq 0
