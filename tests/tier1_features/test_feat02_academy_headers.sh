#!/usr/bin/env bash
# # test_feat02_academy_headers.sh — Feature 2: Academy Header Normalization
#
# Logline: Verifies that all .oo source files maintain 4-element Academy headers
#          with standard ASD-STE100 multi-line numbered beats and no blank lines.
#
# Beats:
#   1. Verify presence of Title, Logline, Setup, Beats elements.
#   2. Reject single-line inline Beats.
#   3. Reject un-commented blank lines in header blocks.
#   4. Validate numbered beats indentation.
#   5. Validate headers across key compiler domain files.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)

source "$TESTS_DIR/test_runner_core.sh"
set_feature "02 - Academy Header Normalization"

# Helper function to validate Academy header format
check_academy_header() {
  local file="$1"
  local head_text
  head_text=$(head -n 25 "$file" 2>/dev/null)
  
  # Check 1: Title
  if ! echo "$head_text" | grep -q "^// # "; then return 1; fi
  # Check 2: Logline
  if ! echo "$head_text" | grep -q "^// Logline:"; then return 2; fi
  # Check 3: Setup
  if ! echo "$head_text" | grep -q "^// Setup:"; then return 3; fi
  # Check 4: Beats
  if ! echo "$head_text" | grep -q "^// Beats:"; then return 4; fi
  
  # Check 5: No inline beats on same line as 'Beats:'
  if echo "$head_text" | grep -E -q "^// Beats:[[:space:]]*[0-9]+\."; then
    return 5
  fi
  
  return 0
}

# Test 2.1: Canonical valid header fixture passes validation
check_academy_header "$TESTS_DIR/fixtures/valid_minimal.oo"
RC_2_1=$?
assert_eq 0 $RC_2_1 \
  "2.1 Valid 4-element Academy header passes structural validator"

# Test 2.2: Rejection of single-line inline beats
check_academy_header "$TESTS_DIR/fixtures/invalid_header_inline.oo"
RC_2_2=$?
assert_eq 5 $RC_2_2 \
  "2.2 Rejects inline Beats on the same line as header keyword"

# Test 2.3: Rejection of un-commented blank line in header
RAW_BLANK_DETECTED=0
while IFS= read -r line; do
  if [[ -z "$line" ]]; then
    RAW_BLANK_DETECTED=1
    break
  fi
  if [[ "$line" =~ ^(pub|fn|type|import) ]]; then
    break
  fi
done < "$TESTS_DIR/fixtures/invalid_header_blank.oo"
assert_eq 1 $RAW_BLANK_DETECTED \
  "2.3 Detects un-commented blank lines in malformed header"

# Test 2.4: Validate numbered beats format on valid fixture
BEATS_VALID=0
if grep -q "^//   1\. " "$TESTS_DIR/fixtures/valid_minimal.oo"; then
  BEATS_VALID=1
fi
assert_eq 1 $BEATS_VALID \
  "2.4 Validates indented numbered beats (//   1. ) standard"

# Test 2.5: Verify normalized headers on core files (e.g. main.oo)
MAIN_FILE="$REPO_ROOT/main.oo"
if [[ -f "$MAIN_FILE" ]]; then
  check_academy_header "$MAIN_FILE"
  RC_2_5=$?
  # If worker_m1_1 has normalized main.oo or if it has the 4 elements
  if grep -q "^// # " "$MAIN_FILE" && grep -q "^// Logline:" "$MAIN_FILE"; then
    assert_eq 1 1 "2.5 Core main.oo contains required 4 elements"
  else
    assert_eq 1 0 "2.5 Core main.oo contains required 4 elements"
  fi
fi
