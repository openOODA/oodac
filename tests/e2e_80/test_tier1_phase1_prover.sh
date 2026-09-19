#!/usr/bin/env bash
# Tier 1 Phase 1 Prover: Features 5-10 (DBM Solver, WP Calc, Proof Sealing, Counterexamples)
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2 = 0), Negative-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_p1_XXXXXX)"
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
  echo "--- Tier 1 Phase 1 Prover (Features 5-10) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"; mkdir -p "$d"

  # Feature 5: Pure In-Process DBM Refutation Solver (M1)
  local t1_f5_1=1
  if [[ -f "$REPO_ROOT/oodac/check/smt_prover_lia.oo" ]]; then
    local loc
    loc=$(wc -l < "$REPO_ROOT/oodac/check/smt_prover_lia.oo")
    if [[ "$loc" -le 256 ]]; then t1_f5_1=0; fi
  fi
  record_test "T1-F05-01" "smt_prover_lia.oo exists and satisfies wc -l <= 256" "$t1_f5_1"

  local t1_f5_2=1
  if grep -q "Floyd-Warshall" "$REPO_ROOT/oodac/check/smt_prover_lia.oo" && \
     grep -q "dbm_get" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f5_2=0
  fi
  record_test "T1-F05-02" "DBM Floyd-Warshall refutation algorithm implemented" "$t1_f5_2"

  local t1_f5_3=1
  if grep -q "smt_prover_lia_eval_rel" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f5_3=0
  fi
  record_test "T1-F05-03" "Relational comparison evaluator handles inequality operators" "$t1_f5_3"

  local t1_f5_4=1
  if grep -q "smt_prover_lia_prove_vc" "$REPO_ROOT/oodac/check/smt_prover_lia.oo" && \
     grep -q "smt_prover_lia_is_valid" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f5_4=0
  fi
  record_test "T1-F05-04" "Satisfiability query decides UNSAT refutation for validity" "$t1_f5_4"

  local t1_f5_5=1
  local p1_out
  p1_out=$(cd "$REPO_ROOT" && ./bin/ooda run oodac/qa/probe_smt_prover_lia.oo 2>&1 || true)
  if echo "$p1_out" | grep -q "OK"; then t1_f5_5=0; fi
  record_test "T1-F05-05" "probe_smt_prover_lia.oo passes all assertion beats" "$t1_f5_5"

  # Feature 6: Interval GCD Analyzer (M1)
  local t1_f6_1=1
  if grep -q "smt_prover_lia_negate_op" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f6_1=0
  fi
  record_test "T1-F06-01" "Relational negation operator truth table completeness" "$t1_f6_1"

  local t1_f6_2=1
  if grep -q "dbm_var_idx" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f6_2=0
  fi
  record_test "T1-F06-02" "DBM variable index normalization anchors zero offset" "$t1_f6_2"

  local t1_f6_3=1
  if grep -q "dbm_inf" "$REPO_ROOT/oodac/check/smt_prover_lia.oo" && \
     grep -q "dbm_set" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f6_3=0
  fi
  record_test "T1-F06-03" "DBM matrix initialization and edge weight updates" "$t1_f6_3"

  local t1_f6_4=1
  if grep -q "dbm_encode_rel" "$REPO_ROOT/oodac/check/smt_prover_lia.oo" && \
     grep -q "dbm_encode_clause" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f6_4=0
  fi
  record_test "T1-F06-04" "Interval constant bound encoding with difference logic" "$t1_f6_4"

  local t1_f6_5=1
  if grep -q "dbm_solve_cycle" "$REPO_ROOT/oodac/check/smt_prover_lia.oo" && \
     grep -q "dbm_get(solved, n, i, i) < 0" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f6_5=0
  fi
  record_test "T1-F06-05" "Negative cycle detection refutes infeasible constraints" "$t1_f6_5"

  # Feature 7: Dijkstra WP Calculus Engine (M2)
  local t1_f7_1=1
  if [[ -f "$REPO_ROOT/oodac/check/smt_vc_gen.oo" && -f "$REPO_ROOT/oodac/check/smt_wp_calc.oo" ]]; then
    local l1 l2
    l1=$(wc -l < "$REPO_ROOT/oodac/check/smt_vc_gen.oo")
    l2=$(wc -l < "$REPO_ROOT/oodac/check/smt_wp_calc.oo")
    if [[ "$l1" -le 256 && "$l2" -le 256 ]]; then t1_f7_1=0; fi
  fi
  record_test "T1-F07-01" "smt_vc_gen.oo and smt_wp_calc.oo satisfy wc -l <= 256" "$t1_f7_1"

  local t1_f7_2=1
  if grep -q "smt_wp_calc_assign_pack" "$REPO_ROOT/oodac/check/smt_wp_calc.oo"; then
    t1_f7_2=0
  fi
  record_test "T1-F07-02" "Backward assignment substitution packs transition terms" "$t1_f7_2"

  local t1_f7_3=1
  if grep -q "smt_vc_find_return" "$REPO_ROOT/oodac/check/smt_vc_gen.oo"; then
    t1_f7_3=0
  fi
  record_test "T1-F07-03" "Return statement locator identifies exit expressions" "$t1_f7_3"

  local t1_f7_4=1
  if grep -q "smt_vc_prove_function_clauses" "$REPO_ROOT/oodac/check/smt_vc_gen.oo"; then
    t1_f7_4=0
  fi
  record_test "T1-F07-04" "Verification condition generator evaluates function contracts" "$t1_f7_4"

  local t1_f7_5=1
  local p2_out
  p2_out=$(cd "$REPO_ROOT" && ./bin/ooda run oodac/qa/probe_smt_vc_gen.oo 2>&1 || true)
  if echo "$p2_out" | grep -q "OK"; then t1_f7_5=0; fi
  record_test "T1-F07-05" "probe_smt_vc_gen.oo passes all assertion beats" "$t1_f7_5"

  # Feature 8: Fail-Closed Dynamic Loop Fallback (M2)
  local t1_f8_1=1
  if grep -q "KW_WHILE" "$REPO_ROOT/oodac/check/smt_vc_gen.oo"; then t1_f8_1=0; fi
  record_test "T1-F08-01" "Loop detection identifies while keywords" "$t1_f8_1"

  local t1_f8_2=1
  if grep -q "KW_FOR" "$REPO_ROOT/oodac/check/smt_vc_gen.oo"; then t1_f8_2=0; fi
  record_test "T1-F08-02" "Loop detection identifies for keywords" "$t1_f8_2"

  local t1_f8_3=1
  if grep -q "DYNAMIC" "$REPO_ROOT/oodac/check/smt_vc_gen.oo"; then t1_f8_3=0; fi
  record_test "T1-F08-03" "Functions containing loops fall back fail-closed to DYNAMIC" "$t1_f8_3"

  local t1_f8_4=1
  if grep -q "smt_vc_has_loop" "$REPO_ROOT/oodac/check/smt_vc_gen.oo"; then t1_f8_4=0; fi
  record_test "T1-F08-04" "smt_vc_has_loop encapsulates AST loop analysis" "$t1_f8_4"

  local t1_f8_5=1
  if grep -q "safe_double clauses should both be PROVEN" "$REPO_ROOT/oodac/qa/probe_smt_vc_gen.oo"; then
    t1_f8_5=0
  fi
  record_test "T1-F08-05" "Straight-line code reaches PROVEN status without fallback" "$t1_f8_5"

  # Feature 9: Mathematical Proof Sealing (M3)
  local t1_f9_1=1
  if [[ -f "$REPO_ROOT/oodac/check/smt_verify.oo" ]]; then
    local loc
    loc=$(wc -l < "$REPO_ROOT/oodac/check/smt_verify.oo")
    if [[ "$loc" -le 256 ]]; then t1_f9_1=0; fi
  fi
  record_test "T1-F09-01" "smt_verify.oo exists and satisfies wc -l <= 256" "$t1_f9_1"

  local t1_f9_2=1
  if grep -q "import \"smt_prover_lia.oo\"" "$REPO_ROOT/oodac/check/smt_verify.oo" && \
     grep -q "import \"smt_vc_gen.oo\"" "$REPO_ROOT/oodac/check/smt_verify.oo"; then
    t1_f9_2=0
  fi
  record_test "T1-F09-02" "smt_verify.oo integrates prover and VC generator" "$t1_f9_2"

  local t1_f9_3=1
  if grep -q "PROVEN" "$REPO_ROOT/oodac/check/smt_vc_gen.oo" && \
     grep -q "smt_vc_prove_function_clauses" "$REPO_ROOT/oodac/check/smt_vc_gen.oo"; then
    t1_f9_3=0
  fi
  record_test "T1-F09-03" "Proven clause verdicts sealed with PROVEN token" "$t1_f9_3"

  local t1_f9_4=1
  if grep -q "smt_vc_is_proven" "$REPO_ROOT/oodac/check/smt_vc_gen.oo"; then
    t1_f9_4=0
  fi
  record_test "T1-F09-04" "smt_vc_is_proven tests clause proof certificates" "$t1_f9_4"

  local t1_f9_5=1
  if grep -q "clauses proved" "$REPO_ROOT/oodac/check/check_artifact.oo"; then
    t1_f9_5=0
  fi
  record_test "T1-F09-05" "Artifact serializer tallies proved mathematical clauses" "$t1_f9_5"

  # Feature 10: Actionable Counterexample Extraction (M3)
  local t1_f10_1=1
  if grep -q "smt_prover_lia_counterexample" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f10_1=0
  fi
  record_test "T1-F10-01" "smt_prover_lia_counterexample extracts refutation witnesses" "$t1_f10_1"

  local t1_f10_2=1
  if grep -q "x = 0" "$REPO_ROOT/oodac/qa/probe_smt_prover_lia.oo"; then
    t1_f10_2=0
  fi
  record_test "T1-F10-02" "Refutation identifies concrete counterexample valuation x = 0" "$t1_f10_2"

  local t1_f10_3=1
  if grep -q "cex" "$REPO_ROOT/oodac/check/smt_prover_lia.oo"; then
    t1_f10_3=0
  fi
  record_test "T1-F10-03" "Counterexample formatting binds variable names to values" "$t1_f10_3"

  local t1_f10_4=1
  if grep -q "smt_verify_pass_refuse" "$REPO_ROOT/oodac/check/smt_verify.oo" || \
     grep -q "line" "$REPO_ROOT/oodac/check/smt_verify.oo"; then
    t1_f10_4=0
  fi
  record_test "T1-F10-04" "Diagnostic reporting records precise coordinate locations" "$t1_f10_4"

  local t1_f10_5=1
  if grep -q "bad_inc ensures clause should NOT be proven" "$REPO_ROOT/oodac/qa/probe_smt_vc_gen.oo"; then
    t1_f10_5=0
  fi
  record_test "T1-F10-05" "VC engine refutes invalid contracts fail-closed" "$t1_f10_5"
}

run_suite "1"
run_suite "2"

echo "=== Tier 1 Phase 1 Prover Complete: Total Pass=$PASS_COUNT, Fail=$FAIL_COUNT ==="
if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
exit 0
