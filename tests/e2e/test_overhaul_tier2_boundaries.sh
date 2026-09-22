#!/usr/bin/env bash
# Tier 2: Boundary & Corner Cases (openOODA Runtime Substrate Overhaul)
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero Ambient.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAR_DIR="$PROJECT_ROOT/oodar"
TMPDIR="$(mktemp -d /tmp/e2e_overhaul_t2_XXXXXX)"
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

echo "--- Pre-compiling Tier 2 Boundary Probes ---"
gcc -O2 -std=c11 -D_GNU_SOURCE -I"$OODAR_DIR" \
  "$OODAR_DIR/qa/tests_overhaul_slab.c" "$OODAR_DIR/oodar.c" \
  -lpthread -ldl -lm -o "$TMPDIR/slab_test"

gcc -O2 -std=c11 -D_GNU_SOURCE -I"$OODAR_DIR" \
  "$OODAR_DIR/qa/tests_overhaul_arena.c" "$OODAR_DIR/oodar.c" \
  -lpthread -ldl -lm -o "$TMPDIR/arena_test"

gcc -O2 -std=c11 -D_GNU_SOURCE -I"$OODAR_DIR" \
  "$OODAR_DIR/qa/tests_overhaul_sandbox.c" "$OODAR_DIR/oodar.c" \
  -lpthread -ldl -lm -o "$TMPDIR/sb_test"

gcc -O2 -std=c11 -fstack-protector-strong -D_GNU_SOURCE -I"$OODAR_DIR" \
  "$OODAR_DIR/qa/tests_overhaul_canary_fuzz.c" "$OODAR_DIR/oodar.c" \
  -lpthread -ldl -lm -o "$TMPDIR/canary_test"

gcc -O2 -std=c11 -D_GNU_SOURCE -I"$OODAR_DIR" \
  "$OODAR_DIR/qa/tests_overhaul_archives.c" "$OODAR_DIR/oodar.c" \
  -lpthread -ldl -lm -o "$TMPDIR/archive_test"

run_tier2_pass() {
  local run_id="$1"
  echo "--- Executing Overhaul Tier 2 Boundary Cases (Run $run_id) ---"

  # Case 1: Execute C Slab Boundary Probe
  local b1=0
  "$TMPDIR/slab_test" >/dev/null 2>&1 || b1=1
  check "T2_B01" "Short-string 15-byte & empty string slab boundaries" "$b1"

  # Case 2: Execute Arena Resets & Quota Probe
  local b2=0
  "$TMPDIR/arena_test" >/dev/null 2>&1 || b2=1
  check "T2_B02" "Bump arena reset & ambient quota boundary traps" "$b2"

  # Case 3: Execute Sandbox Boundary Probe
  local b3=0
  "$TMPDIR/sb_test" >/dev/null 2>&1 || b3=1
  check "T2_B03" "Sandbox empty allowlists & permission boundaries" "$b3"

  # Case 4: Execute Canary Audit & Fuzzing Seed Probe
  local b4=0
  "$TMPDIR/canary_test" >/dev/null 2>&1 || b4=1
  check "T2_B04" "Stack canary smash trap & corrupt seed fallbacks" "$b4"

  # Case 5: Execute Modular Archive Metrics Probe
  local b5=0
  "$TMPDIR/archive_test" >/dev/null 2>&1 || b5=1
  check "T2_B05" "Modular archives symbol availability & size bounds" "$b5"

  # Case 6: Ambient quota edge verification via environment override
  local b6=0
  OO_LIST_AMBIENT_QUOTA=67108864 "$TMPDIR/arena_test" >/dev/null 2>&1 || b6=1
  check "T2_B06" "Ambient quota edge under OO_LIST_AMBIENT_QUOTA=64MB" "$b6"

  # Case 7: Seed boundary edge (OO_FUZZ_SEED=0)
  local b7=0
  OO_FUZZ_SEED=0 "$TMPDIR/canary_test" >/dev/null 2>&1 || b7=1
  check "T2_B07" "Fuzzing seed boundary at OO_FUZZ_SEED=0" "$b7"

  # Case 8: Seed extreme boundary (OO_FUZZ_SEED=18446744073709551615)
  local b8=0
  OO_FUZZ_SEED=18446744073709551615 "$TMPDIR/canary_test" \
    >/dev/null 2>&1 || b8=1
  check "T2_B08" "Fuzzing seed boundary at UINT64_MAX" "$b8"

  # Case 9: Corrupt seed fallback (OO_FUZZ_SEED=malformed_xyz)
  local b9=0
  OO_FUZZ_SEED=malformed_xyz "$TMPDIR/canary_test" >/dev/null 2>&1 || b9=1
  check "T2_B09" "Corrupt seed string fallback handled safely" "$b9"
}

# Double-run execution protocol
echo "=== openOODA E2E Overhaul: Tier 2 Boundary & Corner Cases ==="
run_tier2_pass 1
run_tier2_pass 2

echo "======================================================="
echo "Tier 2 Totals: $PASS Passed, $FAIL Failed"
echo "======================================================="
test "$FAIL" -eq 0
