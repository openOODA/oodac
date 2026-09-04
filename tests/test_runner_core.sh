#!/usr/bin/env bash
# # test_runner_core.sh — Shared Assertion Engine for E2E Test Suite
#
# Logline: Provides standardized assertion macros, test harness state,
#          and reporting helpers for all 4 test tiers.
#
# Beats:
#   1. Initialize counters and terminal formatting.
#   2. Define assertion functions: eq, ne, contains, exit_code, file.
#   3. Provide test case execution wrapper with timing.

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
CURRENT_TIER=""
CURRENT_FEATURE=""

# Color configuration
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  CLR_GREEN="\033[0;32m"
  CLR_RED="\033[0;31m"
  CLR_YELLOW="\033[0;33m"
  CLR_CYAN="\033[0;36m"
  CLR_RESET="\033[0m"
else
  CLR_GREEN=""
  CLR_RED=""
  CLR_YELLOW=""
  CLR_CYAN=""
  CLR_RESET=""
fi

# Set tier context
set_tier() {
  CURRENT_TIER="$1"
  echo -e "\n${CLR_CYAN}=== Tier: $CURRENT_TIER ===${CLR_RESET}"
}

# Set feature context
set_feature() {
  CURRENT_FEATURE="$1"
  echo -e "\n${CLR_YELLOW}--- Feature: $CURRENT_FEATURE ---${CLR_RESET}"
}

# Core assertion: equality
assert_eq() {
  local expected="$1"
  local actual="$2"
  local desc="$3"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${CLR_GREEN}[PASS]${CLR_RESET} $desc"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${CLR_RED}[FAIL]${CLR_RESET} $desc"
    echo "         Expected: '$expected'"
    echo "         Actual:   '$actual'"
    return 1
  fi
}

# Core assertion: string contains
assert_contains() {
  local needle="$1"
  local haystack="$2"
  local desc="$3"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${CLR_GREEN}[PASS]${CLR_RESET} $desc"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${CLR_RED}[FAIL]${CLR_RESET} $desc"
    echo "         Substring '$needle' not found in output"
    return 1
  fi
}

# Core assertion: string does not contain
assert_not_contains() {
  local needle="$1"
  local haystack="$2"
  local desc="$3"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${CLR_GREEN}[PASS]${CLR_RESET} $desc"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${CLR_RED}[FAIL]${CLR_RESET} $desc"
    echo "         Forbidden substring '$needle' was found in output"
    return 1
  fi
}

# Core assertion: exit code match
assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local desc="$3"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ "$expected" -eq "$actual" ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${CLR_GREEN}[PASS]${CLR_RESET} $desc"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${CLR_RED}[FAIL]${CLR_RESET} $desc"
    echo "         Expected exit code $expected, got $actual"
    return 1
  fi
}

# Core assertion: file existence
assert_file_exists() {
  local path="$1"
  local desc="$2"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ -f "$path" ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${CLR_GREEN}[PASS]${CLR_RESET} $desc"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${CLR_RED}[FAIL]${CLR_RESET} $desc"
    echo "         File does not exist: $path"
    return 1
  fi
}

# Core assertion: file absence
assert_file_not_exists() {
  local path="$1"
  local desc="$2"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ ! -e "$path" ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${CLR_GREEN}[PASS]${CLR_RESET} $desc"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${CLR_RED}[FAIL]${CLR_RESET} $desc"
    echo "         Path unexpectedly exists: $path"
    return 1
  fi
}

# Core assertion: integer condition (e.g. <= 256)
assert_le() {
  local actual="$1"
  local max_val="$2"
  local desc="$3"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ "$actual" -le "$max_val" ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${CLR_GREEN}[PASS]${CLR_RESET} $desc"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${CLR_RED}[FAIL]${CLR_RESET} $desc"
    echo "         Value $actual exceeds limit $max_val"
    return 1
  fi
}

# Core assertion: integer condition >= min_val
assert_ge() {
  local actual="$1"
  local min_val="$2"
  local desc="$3"
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  if [[ "$actual" -ge "$min_val" ]]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
    echo -e "  ${CLR_GREEN}[PASS]${CLR_RESET} $desc"
    return 0
  else
    FAILED_TESTS=$((FAILED_TESTS + 1))
    echo -e "  ${CLR_RED}[FAIL]${CLR_RESET} $desc"
    echo "         Value $actual is less than threshold $min_val"
    return 1
  fi
}

# Print final test suite summary
print_summary() {
  local title="$1"
  echo ""
  echo "=================================================="
  echo " $title Test Suite Summary"
  echo "=================================================="
  echo " Total Tests Run: $TOTAL_TESTS"
  echo -e " Passed:          ${CLR_GREEN}$PASSED_TESTS${CLR_RESET}"
  if [[ $FAILED_TESTS -gt 0 ]]; then
    echo -e " Failed:          ${CLR_RED}$FAILED_TESTS${CLR_RESET}"
    echo "=================================================="
    return 1
  else
    echo -e " Failed:          ${CLR_GREEN}0${CLR_RESET}"
    echo "=================================================="
    return 0
  fi
}
