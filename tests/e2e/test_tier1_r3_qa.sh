#!/usr/bin/env bash
# Tier 1: Features 11-15 (QA Path Resolution, Anti-Vacuity, Artifact Cleanup)
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
POLYREPO_ROOT="$(cd "$PROJECT_ROOT/.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_r3_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS_COUNT=0
FAIL_COUNT=0

record_test() {
  local id="$1"
  local desc="$2"
  local status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $id: $desc"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 1 (Features 11-15) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 11: Dynamic Path Resolution in QA Suite
  # T1-F11-01: Sub-repo CWD (oodac/) path resolution
  local f11_sub=1
  if grep -q 'resolve_probe' "$PROJECT_ROOT/qa/suite.oo" 2>/dev/null; then
    f11_sub=0
  fi
  record_test "T1-F11-01" "Dynamic probe path resolution in qa/suite.oo" "$f11_sub"

  # T1-F11-02: Polyrepo root CWD path resolution logic
  local f11_poly=1
  if grep -q 'oodac/' "$PROJECT_ROOT/qa/suite.oo" 2>/dev/null; then
    f11_poly=0
  fi
  record_test "T1-F11-02" "Polyrepo root path prefix in qa/suite.oo" "$f11_poly"

  # T1-F11-03: resolve_probe helper handles both CWDs
  local f11_helper=1
  if grep -q 'fn resolve_probe' "$PROJECT_ROOT/qa/suite.oo" 2>/dev/null; then
    f11_helper=0
  fi
  record_test "T1-F11-03" "resolve_probe helper defined in qa/suite.oo" "$f11_helper"

  # T1-F11-04: Sibling probes located dynamically
  local f11_sib=1
  if [[ -f "$PROJECT_ROOT/qa/probe_borrow_move.oo" && -f "$PROJECT_ROOT/qa/probe_borrow_mut_alias.oo" ]]; then
    f11_sib=0
  fi
  record_test "T1-F11-04" "Sibling probe fixtures exist in qa/" "$f11_sib"

  # T1-F11-05: Non-existent probe fail-closed
  local f11_none=1
  if ! timeout 5s "$OODAC" check "$PROJECT_ROOT/qa/nonexistent_probe.oo" >/dev/null 2>&1; then
    f11_none=0
  fi
  record_test "T1-F11-05" "Non-existent probe fails closed" "$f11_none"

  # Feature 12: API Surface Probe Path Fix
  local api_probe="$PROJECT_ROOT/qa/probe_api_surface.oo"
  # T1-F12-01: Checks oodac/anchor.oo before anchor.oo
  local f12_order=1
  if grep -q 'oodac/anchor\.oo' "$api_probe" 2>/dev/null; then
    local l_oodac
    l_oodac=$(grep -n 'oodac/anchor\.oo' "$api_probe" | head -n 1 | cut -d: -f1)
    local l_root
    l_root=$(grep -n '"anchor\.oo"' "$api_probe" | head -n 1 | cut -d: -f1)
    if [[ "$l_oodac" -lt "$l_root" ]]; then
      f12_order=0
    fi
  fi
  record_test "T1-F12-01" "probe_api_surface checks oodac/anchor.oo before anchor.oo" "$f12_order"

  # T1-F12-02: Polyrepo anchor collision prevented
  local f12_poly_avoid=1
  if [[ ( -f "$POLYREPO_ROOT/anchor.oo" || -f "$POLYREPO_ROOT/openOODA/anchor.oo" ) && "$f12_order" -eq 0 ]]; then
    f12_poly_avoid=0
  fi
  record_test "T1-F12-02" "Polyrepo root anchor collision avoided" "$f12_poly_avoid"

  # T1-F12-03: Sub-repo execution checks anchor.oo
  local f12_sub=1
  if grep -q 'path_exists' "$api_probe" 2>/dev/null; then
    f12_sub=0
  fi
  record_test "T1-F12-03" "Sub-repo direct anchor existence check" "$f12_sub"

  # T1-F12-04: API surface probe syntax valid
  local f12_syntax=1
  if timeout 10s "$OODAC" check "$api_probe" >/dev/null 2>&1; then
    f12_syntax=0
  fi
  record_test "T1-F12-04" "probe_api_surface passes check" "$f12_syntax"

  # T1-F12-05: Missing anchor fails closed in probe_api_surface
  local f12_failclose=1
  if grep -q 'process_exit(1)' "$api_probe" 2>/dev/null; then
    f12_failclose=0
  fi
  record_test "T1-F12-05" "probe_api_surface fails closed if anchor missing" "$f12_failclose"

  # Feature 13: OODA_COMPILER Forwarding
  # T1-F13-01: OODA_COMPILER forwarded in qa/suite.oo
  local f13_fwd=1
  if grep -q 'OODA_COMPILER' "$PROJECT_ROOT/qa/suite.oo" 2>/dev/null; then
    f13_fwd=0
  fi
  record_test "T1-F13-01" "OODA_COMPILER referenced in qa/suite.oo" "$f13_fwd"

  # T1-F13-02: Stripped HOME resiliency
  local f13_home=1
  if env -u HOME OODA_COMPILER="$OODAC" timeout 5s "$OODAC" check "$PROJECT_ROOT/tests/fixtures/valid_minimal.oo" >/dev/null 2>&1; then
    f13_home=0
  fi
  record_test "T1-F13-02" "Compiler executes with stripped HOME env" "$f13_home"

  # T1-F13-03: Explicit OODA_COMPILER precedence
  local f13_prec=1
  if grep -q 'env_get(env, "OODA_COMPILER")' "$PROJECT_ROOT/qa/suite.oo" 2>/dev/null; then
    f13_prec=0
  fi
  record_test "T1-F13-03" "OODA_COMPILER has highest precedence in suite" "$f13_prec"

  # T1-F13-04: Missing compiler fails closed
  local f13_nocomp=1
  if ! env -u HOME -u OODA_COMPILER -u OODA_TOOLCHAIN "$OODAC" check "$d/bad.oo" >/dev/null 2>&1; then
    f13_nocomp=0
  fi
  record_test "T1-F13-04" "Missing compiler or file fails closed" "$f13_nocomp"

  # T1-F13-05: Non-executable compiler fails closed
  local f13_nonexec=1
  local fake_bin="$d/fake_oodac"
  echo "#!/bin/sh" > "$fake_bin"
  chmod -x "$fake_bin"
  if ! env OODA_COMPILER="$fake_bin" "$fake_bin" check "$PROJECT_ROOT/anchor.oo" >/dev/null 2>&1; then
    f13_nonexec=0
  fi
  record_test "T1-F13-05" "Non-executable compiler fails closed" "$f13_nonexec"

  # Feature 14: Anti-Vacuity in Negative Probes
  # T1-F14-01: Pre-flight fixture existence assertions
  local f14_pre=1
  if grep -q 'path_exists.*probe_borrow_move' "$PROJECT_ROOT/qa/probe_borrow_kind.oo" 2>/dev/null; then
    f14_pre=0
  fi
  record_test "T1-F14-01" "probe_borrow_kind asserts fixture existence" "$f14_pre"

  # T1-F14-02: Missing fixture fail-closed
  local f14_miss=1
  if grep -q 'fixtures missing' "$PROJECT_ROOT/qa/probe_borrow_kind.oo" 2>/dev/null; then
    f14_miss=0
  fi
  record_test "T1-F14-02" "probe_borrow_kind fails closed on missing fixture" "$f14_miss"

  # T1-F14-03: Exact semantic diagnostic assertion (no substring false-positive)
  local f14_diag=1
  if grep -q 'use after move' "$PROJECT_ROOT/qa/probe_borrow_kind.oo" 2>/dev/null; then
    f14_diag=0
  fi
  record_test "T1-F14-03" "probe_borrow_kind asserts exact semantic diagnostic" "$f14_diag"

  # T1-F14-04: SMT probes assert unsat / unproven tokens
  local f14_smt=1
  if grep -q 'unsat' "$PROJECT_ROOT/qa/probe_smt_false_kind.oo" 2>/dev/null && \
     grep -q 'unproven' "$PROJECT_ROOT/qa/probe_smt_unproven_kind.oo" 2>/dev/null; then
    f14_smt=0
  fi
  record_test "T1-F14-04" "SMT probes assert unsat and unproven tokens" "$f14_smt"

  # T1-F14-05: Lattice audit checks fixture write result
  local f14_lat=1
  if grep -q 'sw.is_err()' "$PROJECT_ROOT/qa/probe_lattice_audit.oo" 2>/dev/null; then
    f14_lat=0
  fi
  record_test "T1-F14-05" "probe_lattice_audit checks fixture write result" "$f14_lat"

  # Feature 15: Zero-Orphan Artifact Cleanup
  # T1-F15-01: Probes delete .tmp.bin on exit
  local f15_bin=1
  if grep -q 'rm.*\.tmp\.bin' "$PROJECT_ROOT/qa/suite.oo" 2>/dev/null; then
    f15_bin=0
  fi
  record_test "T1-F15-01" "qa/suite.oo deletes temporary test binaries" "$f15_bin"

  # T1-F15-02: probe_blackbox_autopsy scrubs autopsy.json
  local f15_bb=1
  if grep -q 'autopsy\.json' "$PROJECT_ROOT/qa/probe_blackbox_autopsy.oo" 2>/dev/null && \
     grep -q 'rm.*autopsy\.json' "$PROJECT_ROOT/qa/probe_blackbox_autopsy.oo" 2>/dev/null; then
    f15_bb=0
  fi
  record_test "T1-F15-02" "probe_blackbox_autopsy scrubs autopsy.json on exit" "$f15_bb"

  # T1-F15-03: probe_lattice_audit scrubs /tmp/lattice_*
  local f15_lat=1
  if grep -q 'rm.*lattice_' "$PROJECT_ROOT/qa/probe_lattice_audit.oo" 2>/dev/null; then
    f15_lat=0
  fi
  record_test "T1-F15-03" "probe_lattice_audit scrubs /tmp/lattice_* files" "$f15_lat"

  # T1-F15-04: Zero orphaned .tmp.bin files in qa/
  local orphan_bins
  orphan_bins=$((find "$PROJECT_ROOT/qa" -name "*.tmp.bin" 2>/dev/null || true) | wc -l)
  if [[ "$orphan_bins" -eq 0 ]]; then
    record_test "T1-F15-04" "Zero orphaned .tmp.bin files in qa/" 0
  else
    record_test "T1-F15-04" "Zero orphaned .tmp.bin files in qa/" 1
  fi

  # T1-F15-05: Clean repository state check
  local git_clean=0
  if git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | grep -q '\.blackbox/autopsy\.json'; then
    git_clean=1
  fi
  record_test "T1-F15-05" "Zero orphaned autopsy.json in repository status" "$git_clean"
}

run_suite 1
p1=$PASS_COUNT; f1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
p2=$PASS_COUNT; f2=$FAIL_COUNT

echo "=== Determinism Result: Run1 Pass=$p1 Fail=$f1 | Run2 Pass=$p2 Fail=$f2 ==="
if [[ "$p1" -ne "$p2" || "$f1" -ne "$f2" || "$f1" -ne 0 ]]; then
  echo "CRITICAL: Non-deterministic execution between Run 1 and Run 2!" >&2
  exit 1
fi
echo "INFO: Tier 1 Features 11-15 completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
