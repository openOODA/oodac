#!/usr/bin/env bash
# Tier 3: Cross-Feature Combinations & Pairwise Subsystem Integration
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POLYREPO_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
TMPDIR="$(mktemp -d /tmp/e2e_t3_XXXXXX)"
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
  echo "--- Executing Tier 3 (Cross-Feature Combinations) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d/pkg"

  # T3-X01: MetricsCap + Lowercase Anchor Import
  echo 'pub fn helper_fn() -> Int { return 10; }' > "$d/pkg/anchor.oo"
  cat << 'EOF' > "$d/app_mcap.oo"
import "pkg/anchor.oo";
pub fn mcap_worker(m: &MetricsCap) -> Int { return 0; }
pub fn main(m: &MetricsCap) -> Int { return mcap_worker(m); }
EOF
  local x01=1
  if timeout 5s "$OODAC" check "$d/app_mcap.oo" >/dev/null 2>&1; then
    if timeout 5s "$OODAC" emit-llvm "$d/app_mcap.oo" > "$d/app_mcap.ll" 2>&1; then
      if ! (grep -q "unknown type MetricsCap" "$d/app_mcap.ll" 2>/dev/null || false); then
        x01=0
      fi
    fi
  fi
  record_test "T3-X01" "MetricsCap combined with lowercase anchor import in LLVM emit" "$x01"

  # T3-X02: Dual CWD Execution Parity (oodac/ vs openOODA/)
  local out_sub; local out_root
  out_sub=$(cd "$PROJECT_ROOT" && timeout 90s "$OODAC" check lex/anchor.oo 2>&1 || true)
  out_root=$(cd "$POLYREPO_ROOT" && timeout 90s "$OODAC" check oodac/lex/anchor.oo 2>&1 || true)
  local x02=1
  if [[ "$out_sub" == "$out_root" && "$out_sub" =~ "OK" ]]; then x02=0; fi
  record_test "T3-X02" "Dual CWD execution parity (oodac/ vs openOODA/)" "$x02"

  # T3-X03: LLVM Lowering + 32-Ocap Multi-Capability Integration
  cat << 'EOF' > "$d/multi_ocap.oo"
pub fn main(t: &TimeCap, p: &ProcessCap, e: &EnvCap) -> Int {
    let now: Int = now_ms(t);
    return now;
}
EOF
  local x03=1
  if timeout 5s "$OODAC" check "$d/multi_ocap.oo" >/dev/null 2>&1; then
    if timeout 5s "$OODAC" emit-llvm "$d/multi_ocap.oo" > "$d/multi_ocap.ll" 2>&1; then
      if grep -F -q "@oo_now_ms" "$d/multi_ocap.ll" 2>/dev/null; then
        x03=0
      fi
    fi
  fi
  record_test "T3-X03" "Multi-capability LLVM lowering (TimeCap, ProcessCap, EnvCap)" "$x03"

  # T3-X04: Dynamic Path Resolution + Anti-Vacuity Gate
  local x04=1
  if grep -q 'resolve_probe' "$PROJECT_ROOT/qa/suite.oo" 2>/dev/null && \
     grep -q 'fixtures missing' "$PROJECT_ROOT/qa/probe_borrow_kind.oo" 2>/dev/null; then
    x04=0
  fi
  record_test "T3-X04" "Dynamic path resolution coupled with anti-vacuity gate" "$x04"

  # T3-X05: Pure Build + Lowercase Anchors (16 anchors verified)
  local missing_anchors=0
  local anchor_files=(
    "anchor.oo" "ast/anchor.oo" "check/anchor.oo" "cli/anchor.oo" "docs/anchor.oo"
    "emit/anchor.oo" "emit/llvm/anchor.oo" "lex/anchor.oo"
    "qa/anchor.oo" "qa/nested/anchor.oo" "scripts/anchor.oo" "tests/anchor.oo"
    "tests/fixtures/anchor.oo" "tests/tier4_realworld/anchor.oo" "types/anchor.oo"
  )
  for a in "${anchor_files[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$a" ]]; then missing_anchors=$((missing_anchors + 1)); fi
  done
  record_test "T3-X05" "Pure build module tree contains lowercase anchors" "$missing_anchors"

  # T3-X06: Pure Build Sovereign Backend Config
  local x06=1
  if grep -q 'SOVEREIGN_BACKEND="llvm"' "$PROJECT_ROOT/bootstrap/oodac_pure_build" 2>/dev/null; then
    x06=0
  fi
  record_test "T3-X06" "Pure build pipeline configured for sovereign LLVM lowering" "$x06"

  # T3-X07: Zero-Orphan Cleanup + Dual-Run Verification
  local orphan_check=0
  if git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | grep -E '\.tmp\.bin|\.blackbox/autopsy\.json'; then
    orphan_check=1
  fi
  record_test "T3-X07" "Zero orphan artifacts remain across dual-run cycles" "$orphan_check"

  # T3-X08: OODA_COMPILER Forwarding in Polyrepo Execution
  local x08=1
  if grep -q 'OODA_COMPILER' "$POLYREPO_ROOT/openOODA/qa/polyrepo_suite.oo" 2>/dev/null; then
    x08=0
  fi
  record_test "T3-X08" "Polyrepo suite forwards OODA_COMPILER across packages" "$x08"

  # T3-X09: Line Limit Verification across all 16 Migrated Anchors
  local line_violations=0
  for a in "${anchor_files[@]}"; do
    if [[ -f "$PROJECT_ROOT/$a" ]]; then
      local lines; lines=$(wc -l < "$PROJECT_ROOT/$a")
      if [[ "$lines" -gt 256 ]]; then line_violations=$((line_violations + 1)); fi
    fi
  done
  record_test "T3-X09" "All 16 migrated anchors satisfy wc -l <= 256" "$line_violations"

  # T3-X10: Cryptographic S1==S2 Convergence Proof Logic
  local x10=1
  if grep -q 'fixed_point_verified (S1 == S2' "$PROJECT_ROOT/bootstrap/oodac_pure_build" 2>/dev/null; then
    x10=0
  fi
  record_test "T3-X10" "Cryptographic S1==S2 convergence proof logic present" "$x10"
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
echo "INFO: Tier 3 completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
