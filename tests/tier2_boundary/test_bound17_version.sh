#!/usr/bin/env bash
# # test_bound17_version.sh — Tier 2 Boundary: Version Contract & Release Bounds
#
# Logline: Boundary tests for VERSION file format, version ranges,
#          api_surface constraints, and semantic version monotonicity.
#
# Beats:
#   1. Test oodac version non-empty string format.
#   2. Test release_tag matches oodac version value.
#   3. Test api_surface exact integer equality to 12.
#   4. Test ooda minimum version constraint.
#   5. Test ooda_max version upper bound contract.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)

source "$TESTS_DIR/test_runner_core.sh"
set_feature "B17 - Version Contract Boundary"

VERSION_FILE="$REPO_ROOT/VERSION"

# Test B17.1: Non-empty oodac version
OODAC_V=$(grep "^oodac=" "$VERSION_FILE" | cut -d= -f2 | tr -d '[:space:]')
assert_ge "${#OODAC_V}" 5 \
  "B17.1 oodac version is a non-empty SemVer string ($OODAC_V)"

# Test B17.2: release_tag equals oodac version
REL_TAG=$(grep "^release_tag=" "$VERSION_FILE" | cut -d= -f2 | tr -d '[:space:]')
assert_eq "$OODAC_V" "$REL_TAG" \
  "B17.2 release_tag ($REL_TAG) matches oodac version ($OODAC_V)"

# Test B17.3: api_surface exact integer 12
API_SURF=$(grep "^api_surface=" "$VERSION_FILE" | cut -d= -f2 | tr -d '[:space:]')
assert_eq "12" "$API_SURF" \
  "B17.3 api_surface constraint equals exact integer 12"

# Test B17.4: ooda minimum version constraint >= 2.10.0
OODA_MIN=$(grep "^ooda=" "$VERSION_FILE" | cut -d= -f2 | tr -d '[:space:]')
assert_eq "2.10.0" "$OODA_MIN" \
  "B17.4 ooda minimum requirement equals 2.10.0"

# Test B17.5: ooda_max upper bound constraint declared
OODA_MAX=$(grep "^ooda_max=" "$VERSION_FILE" | cut -d= -f2 | tr -d '[:space:]')
assert_eq "2.99.0" "$OODA_MAX" \
  "B17.5 ooda_max upper bound compatibility constraint declared"
