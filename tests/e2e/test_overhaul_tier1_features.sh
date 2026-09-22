#!/usr/bin/env bash
# Tier 1: Feature Coverage (openOODA Runtime Substrate Overhaul)
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero Ambient.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAR_DIR="$PROJECT_ROOT/oodar"
OODAC_DIR="$PROJECT_ROOT/oodac"
TMPDIR="$(mktemp -d /tmp/e2e_overhaul_t1_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS=0
FAIL=0

check() {
  local id="$1" desc="$2" status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $id: $desc"
    FAIL=$((FAIL + 1))
  fi
}

run_tier1_pass() {
  local run_id="$1"
  echo "--- Executing Overhaul Tier 1 Feature Coverage (Run $run_id) ---"

  # Feature 1-9: Substrate Partitioning & Modular Archives
  local f1=0
  test -f "$OODAR_DIR/oodar.c" || f1=1
  check "T1_F01" "Substrate monolithic/aggregate entry exists" "$f1"

  local f2=0
  test -f "$OODAR_DIR/scripts/Makefile" || f2=1
  check "T1_F02" "Substrate Makefile exists and configured" "$f2"

  local f3=0
  grep -q "api_surface=112" "$OODAR_DIR/VERSION" || f3=1
  check "T1_F03" "API surface contract declares 112 modules" "$f3"

  local f4=0
  local actual_c
  actual_c=$(cd "$OODAR_DIR" && find core sec fs net hw app -name '*.c' | wc -l)
  test "$actual_c" -eq 112 || f4=1
  check "T1_F04" "Domain C files count matches 112 exactly" "$f4"

  local f5=0
  test -f "$OODAR_DIR/scripts/lib/liboodar.a" || f5=1
  check "T1_F05" "Substrate archive artifact available" "$f5"

  # Feature 10-14: Compiler Auto-Linking & LLVM Emission
  local f10=0
  test -f "$OODAC_DIR/emit/llvm/ll_need_tab.oo" || f10=1
  check "T1_F10" "LLVM symbol table module exists" "$f10"

  local f11=0
  test -f "$OODAC_DIR/emit/llvm/ll_c_abi.oo" || f11=1
  check "T1_F11" "LLVM C-ABI classification module exists" "$f11"

  local f12=0
  test -f "$OODAC_DIR/cli/cli_oodar.oo" || f12=1
  check "T1_F12" "Compiler substrate resolution module exists" "$f12"

  local f13=0
  test -f "$OODAC_DIR/cli/cli_build.oo" || f13=1
  check "T1_F13" "Compiler build driver module exists" "$f13"

  local f14=0
  test -f "$OODAC_DIR/cli/cli_build_multi.oo" || f14=1
  check "T1_F14" "Compiler multi-TU driver module exists" "$f14"

  # Feature 15-17: Memory & Optimization Substrate
  local f15=0
  test -f "$OODAR_DIR/core/str/str_intern.c" || f15=1
  check "T1_F15" "Short-string static slab module exists" "$f15"

  local f16=0
  test -f "$OODAR_DIR/core/mem/arena.c" || f16=1
  check "T1_F16" "Scoped bump arena module exists" "$f16"

  local f17=0
  grep -q "oo_arena_reset" "$OODAR_DIR/core/mem/arena.c" || f17=1
  check "T1_F17" "Scoped bump arena reset symbol implemented" "$f17"

  # Feature 18-19: Security Hardening & Fuzzing
  local f18=0
  test -f "$OODAR_DIR/scripts/canary_audit.sh" || f18=1
  check "T1_F18" "Target-aware stack canary audit script exists" "$f18"

  local f19=0
  test -f "$OODAR_DIR/qa/tests_fuzz_smoke.c" || f19=1
  check "T1_F19" "Deterministic fuzzing smoke test exists" "$f19"

  # Feature 20-21: Sandboxing Abstraction
  local f20=0
  test -d "$OODAR_DIR/sec/landlock/sandbox" || f20=1
  check "T1_F20" "Cross-platform sandbox module exists" "$f20"

  local f21=0
  test -f "$OODAC_DIR/cli/cli_host_rt.oo" || f21=1
  check "T1_F21" "Host runtime driver module exists" "$f21"

  # Feature 22-26: Governance & Invariants
  local f22=0
  local lines_arena
  lines_arena=$(wc -l < "$OODAR_DIR/core/mem/arena.c")
  test "$lines_arena" -le 256 || f22=1
  check "T1_F22" "Arena core file LOC <= 256 compliance" "$f22"

  local f23=0
  local lines_str
  lines_str=$(wc -l < "$OODAR_DIR/core/str/str_intern.c")
  test "$lines_str" -le 256 || f23=1
  check "T1_F23" "String intern file LOC <= 256 compliance" "$f23"
}

# Double-run execution protocol
echo "=== openOODA E2E Overhaul: Tier 1 Feature Coverage ==="
run_tier1_pass 1
run_tier1_pass 2

echo "======================================================="
echo "Tier 1 Totals: $PASS Passed, $FAIL Failed"
echo "======================================================="
test "$FAIL" -eq 0
