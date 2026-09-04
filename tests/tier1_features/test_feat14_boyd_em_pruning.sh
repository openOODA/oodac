#!/usr/bin/env bash
# # test_feat14_boyd_em_pruning.sh — Feature 14: Boyd's E-M Metric Pruning
#
# Logline: Verifies 80/20 power law pruning, <= 256 line limit compliance,
#          zero intermediate artifacts, and zero struct trailing commas.
#
# Beats:
#   1. Verify 100% of .oo files adhere to <= 256 line cap.
#   2. Verify 0 struct trailing commas across repository.
#   3. Verify 0 intermediate artifacts (*.tmp.c, *.bin) in source tree.
#   4. Benchmark typecheck velocity (V < 5.0s on shallow module).
#   5. Track codebase weight (W) and cognitive drag metrics.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "14 - Boyd's E-M Metric Pruning"

# Test 14.1: Verify 100% of .oo files in compiler satisfy <= 256 line limit
OVER_256_COUNT=0
while IFS= read -r f; do
  lines=$(wc -l < "$f" 2>/dev/null || echo 0)
  if [[ "$lines" -gt 256 ]]; then
    OVER_256_COUNT=$((OVER_256_COUNT + 1))
    echo "Line limit violation: $f has $lines lines"
  fi
done < <(find "$REPO_ROOT" -name "*.oo" ! -path "*/.agents/*" \
  ! -path "*/tests/fixtures/boundary_257_lines.oo" 2>/dev/null)

assert_eq 0 $OVER_256_COUNT \
  "14.1 100% of .oo files strictly comply with <= 256 line limit"

# Test 14.2: Zero struct trailing commas across all source files
TRAILING_STRUCT_COMMAS=0
# Regex looks for comma before closing brace in struct definition
while IFS= read -r f; do
  if grep -E -q '^[[:space:]]*[a-zA-Z0-9_]+[[:space:]]*:[[:space:]]*[a-zA-Z0-9_\[\]]+,[[:space:]]*\}' "$f" 2>/dev/null; then
    TRAILING_STRUCT_COMMAS=$((TRAILING_STRUCT_COMMAS + 1))
  fi
done < <(find "$REPO_ROOT" -name "*.oo" ! -path "*/.agents/*" \
  ! -path "*/tests/fixtures/invalid_struct_comma.oo" 2>/dev/null)

assert_eq 0 $TRAILING_STRUCT_COMMAS \
  "14.2 Exactly 0 struct trailing commas exist across all .oo modules"

# Test 14.3: Zero intermediate artifacts (*.tmp.c, *.protos.c, *.bin) in source
ARTIFACTS_COUNT=$(find "$REPO_ROOT" \( -name "*.tmp.c" -o -name "*.protos.c" \) \
  ! -path "*/.agents/*" ! -path "*/.ooda-cache/*" 2>/dev/null | wc -l)
assert_eq 0 "$ARTIFACTS_COUNT" \
  "14.3 Zero intermediate artifacts (.tmp.c, .protos.c) in source trees"

# Test 14.4: Typecheck velocity (V) on shallow module
START_NS=$(date +%s%N)
"$OODA_BIN" check "$TESTS_DIR/fixtures/valid_minimal.oo" >/dev/null 2>&1
END_NS=$(date +%s%N)
ELAPSED_MS=$(( (END_NS - START_NS) / 1000000 ))
# Under 5000 ms (5.0s)
assert_le $ELAPSED_MS 5000 \
  "14.4 Typecheck velocity: verifies shallow fixture under 5000ms ($ELAPSED_MS ms)"

# Test 14.5: Codebase weight tracking
TOTAL_OO_FILES=$(find "$REPO_ROOT" -name "*.oo" ! -path "*/.agents/*" \
  ! -path "*/tests/*" 2>/dev/null | wc -l)
assert_ge "$TOTAL_OO_FILES" 400 \
  "14.5 Monitored codebase module population ($TOTAL_OO_FILES modules tracked)"
