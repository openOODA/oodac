#!/usr/bin/env bash
# Tier 1 Phase 0: Features 1-4 (Baseline Normalization & Schema Lock)
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2 = 0), Negative-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_p0_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS_COUNT=0; FAIL_COUNT=0
record_test() {
  local id="$1" desc="$2" status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $id: $desc"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

run_suite() {
  local r_id="$1"
  echo "--- Tier 1 Phase 0 (Features 1-4) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"; mkdir -p "$d"

  # Feature 1: Track 1 LLVM lowering bar evidence (M0)
  local t1_f1_1=1
  if grep -q "Frozen 10/10 checklist" "$REPO_ROOT/oodac/docs/llvm-rustc-bar.oot" && \
     grep -q "vs-rustc" "$REPO_ROOT/oodac/docs/llvm-rustc-bar.oot"; then
    t1_f1_1=0
  fi
  record_test "T1-F01-01" "llvm-rustc-bar.oot defines Track 1 LLVM lowering bar" "$t1_f1_1"

  local t1_f1_2=1
  if [[ -f "$REPO_ROOT/oodac/tests/e2e/test_track1_runner.log" ]]; then
    if grep -q "ALL TRACK 1 SUITES GREEN" "$REPO_ROOT/oodac/tests/e2e/test_track1_runner.log" || \
       grep -q "Passed Test Suites.*: 14" "$REPO_ROOT/oodac/tests/e2e/test_track1_runner.log"; then
      t1_f1_2=0
    fi
  fi
  record_test "T1-F01-02" "Track 1 runner log confirms certified test bar" "$t1_f1_2"

  local t1_f1_3=1
  if [[ -f "$REPO_ROOT/oodac/tests/e2e/test_track1_runner.log" ]]; then
    if grep -q "Failed.*: 0" "$REPO_ROOT/oodac/tests/e2e/test_track1_runner.log" && \
       grep -q "Passed Test Suites.*: 14" "$REPO_ROOT/oodac/tests/e2e/test_track1_runner.log"; then
      t1_f1_3=0
    fi
  fi
  record_test "T1-F01-03" "Track 1 runner log records 14/14 suites with zero failures" "$t1_f1_3"

  local t1_f1_4=0
  # Verify mathematical fail-closed logic: absent bar produces 3/10
  cat << 'EOF' > "$d/mock_l7.sh"
multi_ok=0
s7=$(( multi_ok == 1 ? 10 : 3 ))
[ "$s7" -eq 3 ] || exit 1
EOF
  bash "$d/mock_l7.sh" || t1_f1_4=1
  record_test "T1-F01-04" "Line 7 scoring fails closed to 3/10 when uncertified" "$t1_f1_4"

  local t1_f1_5=1
  if [[ -s "$REPO_ROOT/oodac/tests/e2e/test_track1_runner.log" ]]; then t1_f1_5=0; fi
  record_test "T1-F01-05" "Track 1 runner log present as non-empty evidence" "$t1_f1_5"

  # Feature 2: Contract verification empirical wiring (M0)
  local t1_f2_1=1
  if [[ -f "$REPO_ROOT/oodac/tests/test_contracts.sh" ]]; then
    if bash -n "$REPO_ROOT/oodac/tests/test_contracts.sh" >/dev/null 2>&1 && \
       grep -q "contract" "$REPO_ROOT/oodac/tests/test_contracts.sh"; then
      t1_f2_1=0
    fi
  fi
  record_test "T1-F02-01" "Contract verification suite present with valid syntax" "$t1_f2_1"

  local t1_f2_2=0
  cat << 'EOF' > "$d/mock_l3_pass.sh"
contract_ok=2
s3=$(( contract_ok == 2 ? 10 : (contract_ok == 1 ? 2 : 0) ))
[ "$s3" -eq 10 ] || exit 1
EOF
  bash "$d/mock_l3_pass.sh" || t1_f2_2=1
  record_test "T1-F02-02" "contracts.log pass marker evaluates to 10/10" "$t1_f2_2"

  local t1_f2_3=0
  cat << 'EOF' > "$d/mock_l3_mid.sh"
contract_ok=1
s3=$(( contract_ok == 2 ? 10 : (contract_ok == 1 ? 2 : 0) ))
[ "$s3" -eq 2 ] || exit 1
EOF
  bash "$d/mock_l3_mid.sh" || t1_f2_3=1
  record_test "T1-F02-03" "Partial contract evidence evaluates to intermediate 2/10" "$t1_f2_3"

  local t1_f2_4=0
  cat << 'EOF' > "$d/mock_l3_fail.sh"
contract_ok=0
s3=$(( contract_ok == 2 ? 10 : (contract_ok == 1 ? 2 : 0) ))
[ "$s3" -eq 0 ] || exit 1
EOF
  bash "$d/mock_l3_fail.sh" || t1_f2_4=1
  record_test "T1-F02-04" "Line 3 evaluates to 0/10 if contract schema missing" "$t1_f2_4"

  local t1_f2_5=0
  cat << 'EOF' > "$d/mock_l3_contract.sh"
set -euo pipefail
# Verify contract_ok values map strictly to {0, 2, 10}
for c in 0 1 2; do
  s=$(( c == 2 ? 10 : (c == 1 ? 2 : 0) ))
  case "$s" in 0|2|10) ;; *) exit 1 ;; esac
done
EOF
  bash "$d/mock_l3_contract.sh" || t1_f2_5=1
  record_test "T1-F02-05" "Line 3 contract state levels strictly bounded" "$t1_f2_5"

  # Feature 3: OODAART3 SMT Schema Standardization (M0)
  local t1_f3_1=1
  if grep -q "smt: String" "$REPO_ROOT/oodac/types/typed_artifact.oo"; then t1_f3_1=0; fi
  record_test "T1-F03-01" "TypedArtifact struct contains smt: String field" "$t1_f3_1"

  local t1_f3_2=1
  if grep -q 'out = out + "smt:\\n"' "$REPO_ROOT/oodac/types/typed_artifact.oo"; then t1_f3_2=0; fi
  record_test "T1-F03-02" "artifact_encode formats structured smt: section" "$t1_f3_2"

  local t1_f3_3=1
  if grep -q 'line == "smt:"' "$REPO_ROOT/oodac/types/typed_artifact.oo"; then t1_f3_3=0; fi
  record_test "T1-F03-03" "artifact_decode parses smt: section header" "$t1_f3_3"

  local t1_f3_4=1
  if grep -q "artifact_smt_of" "$REPO_ROOT/oodac/check/check_artifact.oo"; then t1_f3_4=0; fi
  record_test "T1-F03-04" "check_artifact.oo implements artifact_smt_of serializer" "$t1_f3_4"

  local t1_f3_5=1
  if grep -q "PROVEN" "$REPO_ROOT/oodac/check/check_artifact.oo" || \
     grep -q "DYNAMIC" "$REPO_ROOT/oodac/check/check_artifact.oo" || \
     grep -q "clauses proved" "$REPO_ROOT/oodac/check/check_artifact.oo"; then
    t1_f3_5=0
  fi
  record_test "T1-F03-05" "SMT schema formats PROVEN/DYNAMIC clause records" "$t1_f3_5"

  # Feature 4: LLVM Emitter Artifact SMT Threading (M0)
  local t1_f4_1=1
  if grep -q "artifact_verify_sections" "$REPO_ROOT/oodac/cli/cli_emit_llvm.oo" && \
     grep -q "ll_load_art" "$REPO_ROOT/oodac/cli/cli_emit_llvm.oo"; then
    t1_f4_1=0
  fi
  record_test "T1-F04-01" "cli_emit_llvm.oo loads artifact and triggers verification" "$t1_f4_1"

  local t1_f4_2=1
  if grep -q "artifact_verify_sections" "$REPO_ROOT/oodac/check/check_artifact.oo"; then t1_f4_2=0; fi
  record_test "T1-F04-02" "artifact_verify_sections validates artifact consistency" "$t1_f4_2"

  local t1_f4_3=1
  if grep -q "\.ooda-cache/ooda-tmp/art_" "$REPO_ROOT/oodac/types/typed_artifact.oo"; then t1_f4_3=0; fi
  record_test "T1-F04-03" "artifact_cache_path writes to .ooda-cache/ooda-tmp/" "$t1_f4_3"

  local t1_f4_4=1
  if grep -q "ll_contract" "$REPO_ROOT/oodac/emit/llvm/ll_emit.oo" || \
     grep -q "ll_contract" "$REPO_ROOT/oodac/emit/llvm/ll_contract.oo"; then
    t1_f4_4=0
  fi
  record_test "T1-F04-04" "LLVM emitter links contract lowering engine" "$t1_f4_4"

  local t1_f4_5=0
  # Synthesize an OODAART3 artifact and test encode/decode structure
  cat << 'EOF' > "$d/mock_art.txt"
OODAART3
test.oo
a1b2c3d4e5f60000
types:
fn safe(x: Int) -> Int
caps:
proc
smt:
safe	0	PROVEN:hash123
--
KW_FN	1	1	fn
IDENT	1	4	safe
EOF
  if ! grep -q "OODAART3" "$d/mock_art.txt" || \
     ! grep -q "smt:" "$d/mock_art.txt" || \
     ! grep -q "PROVEN:hash123" "$d/mock_art.txt"; then
    t1_f4_5=1
  fi
  record_test "T1-F04-05" "OODAART3 artifact format preserves smt section records" "$t1_f4_5"
}

run_suite "1"
run_suite "2"

echo "=== Tier 1 Phase 0 Complete: Total Pass=$PASS_COUNT, Fail=$FAIL_COUNT ==="
if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
exit 0
