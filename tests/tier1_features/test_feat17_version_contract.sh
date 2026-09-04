#!/usr/bin/env bash
# # test_feat17_version_contract.sh — Feature 17: Version Contract & Release Parity
#
# Logline: Verifies VERSION file format, required fields, api_surface count,
#          SemVer syntax compliance, and QA self-test probe execution.
#
# Beats:
#   1. Verify VERSION file presence and accessibility.
#   2. Verify presence of all required contract fields.
#   3. Validate api_surface=12 count matches domain subdirectories.
#   4. Validate SemVer format of declared release.
#   5. Verify QA probe_api_surface.oo execution cleanly passes.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "17 - Version Contract & Release Parity"

VERSION_FILE="$REPO_ROOT/VERSION"

# Test 17.1: Verify VERSION file exists
assert_file_exists "$VERSION_FILE" \
  "17.1 VERSION contract file exists in repository root"

# Test 17.2: Verify presence of all required keys
REQ_KEYS_FOUND=0
grep -q "^oodac=" "$VERSION_FILE" && REQ_KEYS_FOUND=$((REQ_KEYS_FOUND + 1))
grep -q "^release_tag=" "$VERSION_FILE" && REQ_KEYS_FOUND=$((REQ_KEYS_FOUND + 1))
grep -q "^ooda=" "$VERSION_FILE" && REQ_KEYS_FOUND=$((REQ_KEYS_FOUND + 1))
grep -q "^api_surface=" "$VERSION_FILE" && REQ_KEYS_FOUND=$((REQ_KEYS_FOUND + 1))
assert_eq 4 $REQ_KEYS_FOUND \
  "17.2 All required version contract fields (oodac, release_tag, ooda, api_surface) present"

# Test 17.3: Validate api_surface declaration
DECLARED_API=$(grep "^api_surface=" "$VERSION_FILE" | cut -d= -f2)
assert_eq "12" "$DECLARED_API" \
  "17.3 api_surface declared as exactly 12 domains"

# Test 17.4: Validate SemVer format
OODAC_VER=$(grep "^oodac=" "$VERSION_FILE" | cut -d= -f2)
SEMVER_VALID=0
if [[ "$OODAC_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  SEMVER_VALID=1
fi
assert_eq 1 $SEMVER_VALID \
  "17.4 Declared version '$OODAC_VER' matches strict SemVer specification"

# Test 17.5: Verify QA probe_api_surface.oo compiles and passes check
QA_PROBE="$REPO_ROOT/qa/probe_api_surface.oo"
OUT_17_5=$("$OODA_BIN" check "$QA_PROBE" 2>&1)
RC_17_5=$?
assert_exit_code 0 $RC_17_5 \
  "17.5 qa/probe_api_surface.oo compiles cleanly under ooda check"
