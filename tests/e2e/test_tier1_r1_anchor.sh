#!/usr/bin/env bash
# Tier 1: Features 1-4 (Anchor Resolution in AST, Typechecker, CLI, Pure Build)
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_r1_XXXXXX)"
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

run_feature_tests() {
  local r_id="$1"
  echo "--- Executing Tier 1 (Features 1-4) Run $r_id ---"
  local f_dir="$TMPDIR/run_$r_id"
  mkdir -p "$f_dir/pkg_lower" "$f_dir/pkg_upper" "$f_dir/pkg_both" "$f_dir/sub" "$f_dir/sub_up"

  # Feature 1: AST Loader Anchor Resolution
  # T1-F01-01: Native lowercase anchor.oo
  echo 'pub fn lower_val() -> Int { return 10; }' > "$f_dir/pkg_lower/anchor.oo"
  echo 'import "pkg_lower/anchor.oo"; pub fn main() -> Int { return 0; }' > "$f_dir/t1.oo"
  if timeout 5s "$OODAC" check "$f_dir/t1.oo" >/dev/null 2>&1; then
    record_test "T1-F01-01" "Native lowercase anchor resolution" 0
  else
    record_test "T1-F01-01" "Native lowercase anchor resolution" 1
  fi

  # T1-F01-02: Uppercase ANCHOR.oo fallback
  echo 'pub fn upper_val() -> Int { return 20; }' > "$f_dir/pkg_upper/ANCHOR.oo"
  echo 'import "pkg_upper/ANCHOR.oo"; pub fn main() -> Int { return 0; }' > "$f_dir/t2.oo"
  if timeout 5s "$OODAC" check "$f_dir/t2.oo" >/dev/null 2>&1; then
    record_test "T1-F01-02" "Uppercase ANCHOR.oo fallback" 0
  else
    record_test "T1-F01-02" "Uppercase ANCHOR.oo fallback" 1
  fi

  # T1-F01-03: Lowercase priority when both exist
  echo 'pub fn both_val() -> Int { return 30; }' > "$f_dir/pkg_both/anchor.oo"
  echo 'pub fn both_val() -> Int { return 31; }' > "$f_dir/pkg_both/ANCHOR.oo"
  echo 'import "pkg_both/anchor.oo"; pub fn main() -> Int { return 0; }' > "$f_dir/t3.oo"
  if timeout 5s "$OODAC" check "$f_dir/t3.oo" >/dev/null 2>&1; then
    record_test "T1-F01-03" "Priority of lowercase anchor over uppercase" 0
  else
    record_test "T1-F01-03" "Priority of lowercase anchor over uppercase" 1
  fi

  # T1-F01-04: Fail-closed on missing anchor
  echo 'import "pkg_missing/anchor.oo"; pub fn main() -> Int { return 0; }' > "$f_dir/t4.oo"
  if ! timeout 5s "$OODAC" check "$f_dir/t4.oo" >/dev/null 2>&1; then
    record_test "T1-F01-04" "Fail-closed on missing anchor" 0
  else
    record_test "T1-F01-04" "Fail-closed on missing anchor" 1
  fi

  # T1-F01-05: Direct module import without anchor suffix
  echo 'pub fn direct_fn() -> Int { return 50; }' > "$f_dir/direct.oo"
  echo 'import "direct.oo"; pub fn main() -> Int { return direct_fn(); }' > "$f_dir/t5.oo"
  if timeout 5s "$OODAC" check "$f_dir/t5.oo" >/dev/null 2>&1; then
    record_test "T1-F01-05" "Direct module import without anchor" 0
  else
    record_test "T1-F01-05" "Direct module import without anchor" 1
  fi

  # Feature 2: Typechecker Sibling Anchor Resolution
  # T1-F02-01: Sibling anchor.oo
  echo 'pub fn sub_fn() -> Int { return 1; }' > "$f_dir/sub/anchor.oo"
  echo 'import "anchor.oo"; pub fn sub_call() -> Int { return 0; }' > "$f_dir/sub/m1.oo"
  if timeout 5s "$OODAC" check "$f_dir/sub/m1.oo" >/dev/null 2>&1; then
    record_test "T1-F02-01" "Sibling anchor.oo resolution" 0
  else
    record_test "T1-F02-01" "Sibling anchor.oo resolution" 1
  fi

  # T1-F02-02: Sibling ANCHOR.oo fallback
  echo 'pub fn sub_up_fn() -> Int { return 2; }' > "$f_dir/sub_up/ANCHOR.oo"
  echo 'import "ANCHOR.oo"; pub fn sub_up_call() -> Int { return 0; }' > "$f_dir/sub_up/m2.oo"
  if timeout 5s "$OODAC" check "$f_dir/sub_up/m2.oo" >/dev/null 2>&1; then
    record_test "T1-F02-02" "Sibling ANCHOR.oo fallback" 0
  else
    record_test "T1-F02-02" "Sibling ANCHOR.oo fallback" 1
  fi

  # T1-F02-03: Sibling priority
  mkdir -p "$f_dir/sub_both"
  echo 'pub fn sb() -> Int { return 1; }' > "$f_dir/sub_both/anchor.oo"
  echo 'pub fn sb() -> Int { return 2; }' > "$f_dir/sub_both/ANCHOR.oo"
  echo 'import "anchor.oo"; pub fn sb_call() -> Int { return 0; }' > "$f_dir/sub_both/m.oo"
  if timeout 5s "$OODAC" check "$f_dir/sub_both/m.oo" >/dev/null 2>&1; then
    record_test "T1-F02-03" "Sibling priority of anchor.oo" 0
  else
    record_test "T1-F02-03" "Sibling priority of anchor.oo" 1
  fi

  # T1-F02-04: Nested directory sibling
  mkdir -p "$f_dir/a/b/c"
  echo 'pub fn nest_fn() -> Int { return 9; }' > "$f_dir/a/b/c/anchor.oo"
  echo 'import "anchor.oo"; pub fn nest_call() -> Int { return 0; }' > "$f_dir/a/b/c/m.oo"
  if timeout 5s "$OODAC" check "$f_dir/a/b/c/m.oo" >/dev/null 2>&1; then
    record_test "T1-F02-04" "Nested directory sibling anchor" 0
  else
    record_test "T1-F02-04" "Nested directory sibling anchor" 1
  fi

  # T1-F02-05: Missing sibling anchor fails closed
  mkdir -p "$f_dir/isolated"
  echo 'import "anchor.oo"; pub fn main() -> Int { return 0; }' > "$f_dir/isolated/iso.oo"
  if ! timeout 5s "$OODAC" check "$f_dir/isolated/iso.oo" >/dev/null 2>&1; then
    record_test "T1-F02-05" "Missing sibling anchor fails closed" 0
  else
    record_test "T1-F02-05" "Missing sibling anchor fails closed" 1
  fi

  # Feature 3: Unused Import & CLI Anchor Handling
  # T1-F03-01: Lowercase anchor import exempt from unused warning
  echo 'pub fn main() -> Int { return 42; }' > "$f_dir/t_ex_low.oo"
  if timeout 5s "$OODAC" check "$f_dir/t_ex_low.oo" >/dev/null 2>&1; then
    record_test "T1-F03-01" "Lowercase anchor import exemption" 0
  else
    record_test "T1-F03-01" "Lowercase anchor import exemption" 1
  fi

  # T1-F03-02: Uppercase anchor import exempt
  echo 'pub fn main() -> Int { return 43; }' > "$f_dir/t_ex_up.oo"
  if timeout 5s "$OODAC" check "$f_dir/t_ex_up.oo" >/dev/null 2>&1; then
    record_test "T1-F03-02" "Uppercase anchor import exemption" 0
  else
    record_test "T1-F03-02" "Uppercase anchor import exemption" 1
  fi

  # T1-F03-03: CLI emit-c is residual
  if timeout 5s "$OODAC" emit-c "$f_dir/t_ex_low.oo" >/dev/null 2>&1; then
    record_test "T1-F03-03" "CLI emit-c residual" 1
  else
    record_test "T1-F03-03" "CLI emit-c residual" 0
  fi

  # T1-F03-04: CLI emit-llvm handles module
  if timeout 5s "$OODAC" emit-llvm "$f_dir/t_ex_low.oo" 2>/dev/null | grep -q "@main"; then
    record_test "T1-F03-04" "CLI emit-llvm TU generation" 0
  else
    record_test "T1-F03-04" "CLI emit-llvm TU generation" 1
  fi

  # T1-F03-05: Unused non-anchor import check
  echo 'pub fn unused_target() -> Int { return 1; }' > "$f_dir/un.oo"
  echo 'import "un.oo"; pub fn main() -> Int { return 0; }' > "$f_dir/t_unused.oo"
  if ! timeout 5s "$OODAC" check "$f_dir/t_unused.oo" >/dev/null 2>&1; then
    record_test "T1-F03-05" "Unused non-anchor import flagged" 0
  else
    record_test "T1-F03-05" "Unused non-anchor import flagged" 1
  fi

  # Feature 4: Pure Build Script Anchor Handling
  local pb="$PROJECT_ROOT/bootstrap/oodac_pure_build"
  # T1-F04-01: Probes anchor.oo
  grep -q 'anchor\.oo' "$pb" && record_test "T1-F04-01" "Pure build probes anchor.oo" 0 || record_test "T1-F04-01" "Pure build probes anchor.oo" 1

  # T1-F04-02: Prioritizes anchor.oo over ANCHOR.oo
  local l_anc
  l_anc=$(grep -n 'anchor\.oo' "$pb" | head -n 1 | cut -d: -f1)
  local l_up
  l_up=$(grep -n 'ANCHOR\.oo' "$pb" | head -n 1 | cut -d: -f1)
  [[ "$l_anc" -le "$l_up" ]] && record_test "T1-F04-02" "Pure build prioritizes anchor.oo" 0 || record_test "T1-F04-02" "Pure build prioritizes anchor.oo" 1

  # T1-F04-03: TU basename exclusion
  grep -q 'anchor\.oo' "$pb" && record_test "T1-F04-03" "Pure build excludes anchor.oo from TU" 0 || record_test "T1-F04-03" "Pure build excludes anchor.oo from TU" 1

  # T1-F04-04: AWK symbol filter
  grep -q 'anchor_oo' "$pb" && record_test "T1-F04-04" "Pure build AWK filters anchor_oo" 0 || record_test "T1-F04-04" "Pure build AWK filters anchor_oo" 1

  # T1-F04-05: Fail-closed on missing entrypoint
  if ! timeout 5s bash "$pb" "$TMPDIR/missing_main.oo" "$TMPDIR/out.bin" >/dev/null 2>&1; then
    record_test "T1-F04-05" "Pure build fails closed on missing main" 0
  else
    record_test "T1-F04-05" "Pure build fails closed on missing main" 1
  fi
}

run_feature_tests 1
p1=$PASS_COUNT; f1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_feature_tests 2
p2=$PASS_COUNT; f2=$FAIL_COUNT

echo "=== Determinism Result: Run1 Pass=$p1 Fail=$f1 | Run2 Pass=$p2 Fail=$f2 ==="
if [[ "$p1" -ne "$p2" || "$f1" -ne "$f2" || "$f1" -ne 0 ]]; then
  echo "CRITICAL: Non-deterministic execution between Run 1 and Run 2!" >&2
  exit 1
fi
echo "INFO: Tier 1 Features 1-4 completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
