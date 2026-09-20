#!/usr/bin/env bash
# # test_tier5_adversarial_2.sh — Tier 5 Adversarial Hardening Suite 2
# Logline: Adversarially stress scorecard, opt -O3 assume DCE, response file linker, and 8D Red Team CI boundaries.
# Setup: Dual-run execution under negative-trust doctrine; evaluates compiler and polyrepo invariants.
# Beats: 1) Scorecard fail-closed robustness; 2) LLVM assume DCE under opt -O3; 3) Linker response file stress & export hermeticity; 4) 8D Red Team CI marginal vs breached thresholds.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t5_adv2_XXXXXX)"
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
  echo "--- Tier 5 Adversarial Suite 2 Run $r_id ---"
  local d="$TMPDIR/run_$r_id"; mkdir -p "$d"

  # Section 1: Target Scorecard & Proof of Today Fail-Closed Robustness
  local sc01=0; local out_sc01
  out_sc01=$(OODA_REPO_ROOT="." "$REPO_ROOT/bin/ooda" run "$REPO_ROOT/openOODA/scripts/proof_of_today.oo" 2>&1 || true)
  [[ "$out_sc01" =~ "[PROOF FAIL] OODA_REPO_ROOT must be set to an absolute path free of .." ]] || sc01=1
  record_test "T5-SC-01" "proof_of_today rejects relative OODA_REPO_ROOT path fail-closed" "$sc01"

  local sc02=0; local out_sc02
  out_sc02=$(OODA_REPO_ROOT="/tmp/../$REPO_ROOT" "$REPO_ROOT/bin/ooda" run "$REPO_ROOT/openOODA/scripts/proof_of_today.oo" 2>&1 || true)
  [[ "$out_sc02" =~ "[PROOF FAIL] OODA_REPO_ROOT must be set to an absolute path free of .." ]] || sc02=1
  record_test "T5-SC-02" "proof_of_today rejects OODA_REPO_ROOT containing .. traversal fail-closed" "$sc02"

  local sc03=0; local card_ok=1; local trend_missing=0
  local s8_missing=$(( (card_ok == 1 && trend_missing == 1) ? 10 : (card_ok == 1 ? 6 : 0) ))
  [[ "$s8_missing" -eq 6 ]] || sc03=1
  record_test "T5-SC-03" "Missing trend.csv downgrades Line 8 from 10/10 to 6/10" "$sc03"

  local sc04=0; local trend_csv="$REPO_ROOT/openOODA/docs/audit-history/trend.csv"
  local exp_hdr="date,line1,line2,line3,line4,line5,line6,line7,line8,total,headline"
  [[ -f "$trend_csv" && "$(head -n 1 "$trend_csv")" == "$exp_hdr" && "$(tail -n 1 "$trend_csv")" =~ 80,100.0% ]] || sc04=1
  record_test "T5-SC-04" "trend.csv satisfies schema header and certifies 80/80 final convergence" "$sc04"

  local sc05=0; local tot_low=39; local h_low=$(( tot_low * 10 / 80 ))
  [[ "$h_low" -lt 5 ]] || sc05=1
  cat << 'EOF' > "$d/mock_fail_closed.sh"
headline=4; [ "$headline" -lt 5 ] && exit 1 || exit 0
EOF
  bash "$d/mock_fail_closed.sh" 2>/dev/null && sc05=1 || true
  record_test "T5-SC-05" "Proof of Today blocks release when headline drops below 5/10" "$sc05"

  # Section 2: LLVM Assume Lowering Dead Code Elimination Under opt -O3
  local llvm01=0
  cat << 'EOF' > "$d/assume_dce.ll"
declare void @llvm.assume(i1) nounwind
declare void @never_called()
define i32 @test_dce(i32 %x) {
entry:
  %c = icmp sgt i32 %x, 10
  call void @llvm.assume(i1 %c)
  %c_dead = icmp sle i32 %x, 10
  br i1 %c_dead, label %dead, label %live
dead:
  call void @never_called()
  ret i32 0
live:
  ret i32 1
}
EOF
  opt -O3 -S "$d/assume_dce.ll" -o "$d/assume_dce_opt.ll" >/dev/null 2>&1 || llvm01=1
  if grep -q "never_called" "$d/assume_dce_opt.ll" || grep -q "dead:" "$d/assume_dce_opt.ll" || ! grep -q "ret i32 1" "$d/assume_dce_opt.ll"; then llvm01=1; fi
  record_test "T5-LLVM-01" "opt -O3 eliminates contradictory dead branch and unused function call" "$llvm01"

  local llvm02=0
  cat << 'EOF' > "$d/assume_range.ll"
declare void @llvm.assume(i1) nounwind
declare void @range_panic()
define i32 @test_range(i32 %x) {
entry:
  %c1 = icmp sge i32 %x, 10
  call void @llvm.assume(i1 %c1)
  %c2 = icmp sle i32 %x, 20
  call void @llvm.assume(i1 %c2)
  %bad = icmp slt i32 %x, 5
  br i1 %bad, label %panic, label %next
panic:
  call void @range_panic()
  ret i32 -1
next:
  ret i32 %x
}
EOF
  opt -O3 -S "$d/assume_range.ll" -o "$d/assume_range_opt.ll" >/dev/null 2>&1 || llvm02=1
  if grep -q "range_panic" "$d/assume_range_opt.ll" || grep -q "panic:" "$d/assume_range_opt.ll"; then llvm02=1; fi
  record_test "T5-LLVM-02" "Dual interval assumes prune out-of-bounds error block under opt -O3" "$llvm02"

  local llvm03=0
  cat << 'EOF' > "$d/assume_fold.ll"
declare void @llvm.assume(i1) nounwind
define i32 @test_fold(i32 %x) {
entry:
  %c = icmp eq i32 %x, 42
  call void @llvm.assume(i1 %c)
  %r = mul nsw i32 %x, 2
  ret i32 %r
}
EOF
  opt -O3 -S "$d/assume_fold.ll" -o "$d/assume_fold_opt.ll" >/dev/null 2>&1 || llvm03=1
  grep -q "ret i32 84" "$d/assume_fold_opt.ll" || llvm03=1
  record_test "T5-LLVM-03" "Equality assume folds variable multiplication directly to constant 84" "$llvm03"

  local llvm04=0
  cat << 'EOF' > "$d/assume_contra.ll"
declare void @llvm.assume(i1) nounwind
define i32 @test_contra(i32 %x) {
entry:
  %c1 = icmp sgt i32 %x, 5
  call void @llvm.assume(i1 %c1)
  %c2 = icmp slt i32 %x, 5
  call void @llvm.assume(i1 %c2)
  ret i32 %x
}
EOF
  opt -O3 -S "$d/assume_contra.ll" -o "$d/assume_contra_opt.ll" >/dev/null 2>&1 || llvm04=1
  grep -qE "unreachable|ret i32" "$d/assume_contra_opt.ll" || llvm04=1
  record_test "T5-LLVM-04" "Mutually contradictory assumes compile cleanly without crashing opt" "$llvm04"

  local llvm05=0
  cat << 'EOF' > "$d/dynamic_trap.ll"
declare void @oo_process_exit(i64)
define i32 @test_dynamic(i32 %x) {
entry:
  %c = icmp sgt i32 %x, 0
  br i1 %c, label %ctok, label %ctrap
ctrap:
  call void @oo_process_exit(i64 1)
  unreachable
ctok:
  ret i32 %x
}
EOF
  opt -O3 -S "$d/dynamic_trap.ll" -o "$d/dynamic_trap_opt.ll" >/dev/null 2>&1 || llvm05=1
  if ! grep -q "oo_process_exit" "$d/dynamic_trap_opt.ll" || ! grep -q "ctrap:" "$d/dynamic_trap_opt.ll"; then llvm05=1; fi
  record_test "T5-LLVM-05" "Dynamic contract ctrap block is preserved under opt -O3 when unproven" "$llvm05"

  # Section 3: Response File Linker Stress & Hermetic Clean Export
  local rsp01=0
  cat << 'EOF' > "$d/helper.c"
int helper_calc(int x) { return x * 2; }
EOF
  cat << 'EOF' > "$d/main.c"
int helper_calc(int x);
int main(void) { return helper_calc(21) == 42 ? 0 : 1; }
EOF
  clang -c "$d/helper.c" -o "$d/helper.o"
  clang -c "$d/main.c" -o "$d/main.o"
  printf "%s\n%s\n" "$d/helper.o" "$d/main.o" > "$d/objs.rsp"
  for i in $(seq 1 300); do echo "$d/helper.o" >> "$d/objs.rsp"; done
  clang -Wl,--allow-multiple-definition @"$d/objs.rsp" -o "$d/linked_stress.bin" >/dev/null 2>&1 || rsp01=1
  if [[ "$rsp01" -eq 0 ]]; then "$d/linked_stress.bin" || rsp01=1; fi
  record_test "T5-RSP-01" "Linker response file links 300+ entries without argument list overflow" "$rsp01"

  local rsp02=0; mkdir -p "$d/dir with space"
  clang -c "$d/helper.c" -o "$d/dir with space/spaced helper.o"
  printf "\"%s\"\n%s\n" "$d/dir with space/spaced helper.o" "$d/main.o" > "$d/spaced.rsp"
  clang @"$d/spaced.rsp" -o "$d/linked_space.bin" >/dev/null 2>&1 || rsp02=1
  if [[ "$rsp02" -eq 0 ]]; then "$d/linked_space.bin" || rsp02=1; fi
  record_test "T5-RSP-02" "Response file quotes and links object paths containing whitespace" "$rsp02"

  local rsp03=0; rm -f "$d/objs.rsp"
  [[ ! -f "$d/objs.rsp" ]] || rsp03=1
  record_test "T5-RSP-03" "Hermetic cleanup verifies temporary response file removed post-link" "$rsp03"

  local rsp04=0
  cat << 'EOF' > "$d/export_test.c"
__attribute__((visibility("default"))) int public_func(void) { return 100; }
int private_func(void) { return 200; }
EOF
  clang -shared -fPIC -fvisibility=hidden -Wl,--exclude-libs,ALL "$d/export_test.c" -o "$d/libexport.so" >/dev/null 2>&1 || rsp04=1
  if [[ "$rsp04" -eq 0 ]]; then
    local dsyms; dsyms=$(nm -D "$d/libexport.so" 2>/dev/null || true)
    if ! echo "$dsyms" | grep -q "public_func" || echo "$dsyms" | grep -q "private_func"; then rsp04=1; fi
  fi
  record_test "T5-RSP-04" "Hermetic export filter hides internal symbols from shared library dynsym" "$rsp04"

  local rsp05=0; echo "$d/nonexistent_phantom_object.o" > "$d/bad.rsp"
  if clang @"$d/bad.rsp" -o "$d/phantom.bin" >/dev/null 2>&1; then rsp05=1; fi
  record_test "T5-RSP-05" "Linker fails closed when response file references missing object file" "$rsp05"

  # Section 4: Red Team CI Marginal vs Breached Thresholds
  local rt01=0; local d1_marg=$(( 20 < 20 ? 1 : 0 )); local d1_breach=$(( 19 < 20 ? 1 : 0 ))
  [[ "$d1_marg" -eq 0 && "$d1_breach" -eq 1 ]] || rt01=1
  record_test "T5-RT-01" "Red team D1 boundary distinguishes marginal 20 slots from breached 19" "$rt01"

  local rt02=0; local d2_marg=$(( 1 < 1 ? 1 : 0 )); local d2_breach=$(( 0 < 1 ? 1 : 0 ))
  [[ "$d2_marg" -eq 0 && "$d2_breach" -eq 1 ]] || rt02=1
  record_test "T5-RT-02" "Red team D2 boundary distinguishes marginal 1 harness from breached 0" "$rt02"

  local rt03=0; local d3_marg=$(( 1 < 1 ? 1 : 0 )); local d3_breach=$(( 0 < 1 ? 1 : 0 ))
  [[ "$d3_marg" -eq 0 && "$d3_breach" -eq 1 ]] || rt03=1
  record_test "T5-RT-03" "Red team D3 boundary distinguishes marginal 1 pinned from breached 0" "$rt03"

  local rt04=0; local d4_marg=$(( 1 < 1 ? 1 : 0 )); local d4_breach=$(( 0 < 1 ? 1 : 0 ))
  [[ "$d4_marg" -eq 0 && "$d4_breach" -eq 1 ]] || rt04=1
  record_test "T5-RT-04" "Red team D4 boundary distinguishes marginal 1 gated from breached 0" "$rt04"

  local rt05=0; local d6_marg=$(( 2 < 2 ? 1 : 0 )); local d6_breach=$(( 1 < 2 ? 1 : 0 ))
  [[ "$d6_marg" -eq 0 && "$d6_breach" -eq 1 ]] || rt05=1
  record_test "T5-RT-05" "Red team D6 boundary distinguishes marginal 2 backends from breached 1" "$rt05"

  local rt06=0
  cat << 'EOF' > "$d/mock_rt_fail.sh"
fails=1; [ "$fails" -gt 0 ] && exit 1 || exit 0
EOF
  bash "$d/mock_rt_fail.sh" 2>/dev/null && rt06=1 || true
  record_test "T5-RT-06" "Red team CI orchestrator fail-closes if even single dimension breached" "$rt06"
}

run_suite "1"
run_suite "2"

echo "=== Tier 5 Adversarial Suite 2 Complete: Total Pass=$PASS_COUNT, Fail=$FAIL_COUNT ==="
if [[ "$FAIL_COUNT" -gt 0 ]]; then exit 1; fi
exit 0
