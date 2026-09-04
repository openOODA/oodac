#!/usr/bin/env bash
# # adversarial_m2_challenger.sh — Milestone 2 Empirical Challenger Test Suite
#
# Logline: Adversarially verifies absence of synthetic cheats and genuine execution
#          of normalized and inlined modules across LLVM, AArch64, C, and x86 backends.
#
# Beats:
#   1. Verify complete elimination of synthetic cheats (aarch64_fold_hello).
#   2. Stress-test AArch64 backend & entry gate (aarch64_entry_gate.oo).
#   3. Stress-test LLVM backend & lowering module (llvm_emit_lowering.oo).
#   4. Stress-test C backend & inlined secret taint module (c_emit_secret.oo).
#   5. Stress-test x86 backend & inlined SSA emission (x86_emit.oo).
#   6. Verify line limits and structural invariants across modified modules.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
OODAC_BIN="$REPO_ROOT/bin/oodac"

source "$SCRIPT_DIR/test_runner_core.sh"

set_tier "Challenger 2 - Milestone 2 Adversarial Verification"

# ==============================================================================
# SECTION 1: Synthetic Cheat Absence Verification
# ==============================================================================
set_feature "Cheat Elimination: aarch64_fold_hello"

# 1.1: Verify aarch64_emit_fold.oo is completely absent from filesystem
assert_file_not_exists "$REPO_ROOT/emit/aarch64/aarch64_emit_fold.oo" \
  "1.1 aarch64_emit_fold.oo does not exist"

# 1.2: Verify zero occurrences of aarch64_fold_hello in any .oo source file
CHEAT_OO_COUNT=$(find "$REPO_ROOT/ast" "$REPO_ROOT/check" "$REPO_ROOT/cli" \
  "$REPO_ROOT/emit" "$REPO_ROOT/lex" "$REPO_ROOT/types" "$REPO_ROOT/vm" \
  "$REPO_ROOT/qa" -name "*.oo" -exec grep -Hn "aarch64_fold_hello" {} + 2>/dev/null | wc -l)
assert_eq "0" "$CHEAT_OO_COUNT" \
  "1.2 aarch64_fold_hello is 100% purged from all compiler source .oo modules"

# 1.3: Verify aarch64_entry_gate.oo does not contain fold cheat call
GATE_CHEAT=$(grep -c "aarch64_fold_hello" "$REPO_ROOT/emit/aarch64/aarch64_entry_gate.oo" 2>/dev/null || true)
assert_eq "0" "$GATE_CHEAT" \
  "1.3 aarch64_entry_gate.oo has 0 cheat bypass references"

# 1.4: Adversarial Hello fixture: must NOT cheat-pass; must fail closed with leftover
OUT_1_4=$("$OODAC_BIN" emit-aarch64 "$REPO_ROOT/fixtures/hello.oo" 2>&1 || true)
assert_contains "ERR" "$OUT_1_4" \
  "1.4 fixtures/hello.oo fails closed with ERR instead of cheat-passing"
assert_contains "leftover" "$OUT_1_4" \
  "1.4 fixtures/hello.oo reports genuine leftover diagnostic"

# ==============================================================================
# SECTION 2: AArch64 Backend & Entry Gate (aarch64_entry_gate.oo)
# ==============================================================================
set_feature "AArch64 Backend & Entry Gate Execution"

# 2.1: Renamed module exists under canonical name
assert_file_exists "$REPO_ROOT/emit/aarch64/aarch64_entry_gate.oo" \
  "2.1 aarch64_entry_gate.oo exists"
assert_file_not_exists "$REPO_ROOT/emit/aarch64/aarch64_leftover_gate.oo" \
  "2.1 aarch64_leftover_gate.oo does not exist"

# 2.2: Fail closed on missing fn main
OUT_2_2=$("$OODAC_BIN" emit-aarch64 "$SCRIPT_DIR/fixtures/valid_minimal.oo" 2>&1 || true)
assert_contains "need fn main" "$OUT_2_2" \
  "2.2 aarch64_entry_gate refuses source without fn main"

# 2.3: Fail closed on empty source
TMP_EMPTY=$(mktemp "$SCRIPT_DIR/fixtures/temp_empty_XXXXXX.oo")
touch "$TMP_EMPTY"
OUT_2_3=$("$OODAC_BIN" emit-aarch64 "$TMP_EMPTY" 2>&1 || true)
rm -f "$TMP_EMPTY"
assert_contains "empty" "$OUT_2_3" \
  "2.3 aarch64 emitter refuses empty source"

# 2.4: Genuine execution of constrained AArch64 code
OUT_2_4=$("$OODAC_BIN" emit-aarch64 "$SCRIPT_DIR/fixtures/challenger_aarch64_sample.oo" 2>&1)
RC_2_4=$?
assert_exit_code 0 $RC_2_4 \
  "2.4 challenger_aarch64_sample.oo compiles cleanly under emit-aarch64"
assert_contains ".arch armv8-a" "$OUT_2_4" \
  "2.4 output contains armv8-a architecture directive"
assert_contains ".globl _start" "$OUT_2_4" \
  "2.4 output contains genuine _start entry symbol"

# ==============================================================================
# SECTION 3: LLVM Backend & Lowering Module (llvm_emit_lowering.oo)
# ==============================================================================
set_feature "LLVM Backend & Lowering Execution"

# 3.1: Renamed module exists under canonical name
assert_file_exists "$REPO_ROOT/emit/llvm/llvm_emit_lowering.oo" \
  "3.1 llvm_emit_lowering.oo exists"
assert_file_not_exists "$REPO_ROOT/emit/llvm/llvm_emit_shims.oo" \
  "3.1 llvm_emit_shims.oo does not exist"

# 3.2: Verify all 7 importing modules in emit/llvm/ import llvm_emit_lowering.oo
LLVM_IMPORTS=$(grep -l "llvm_emit_lowering.oo" "$REPO_ROOT/emit/llvm/"*.oo | wc -l)
assert_eq "7" "$LLVM_IMPORTS" \
  "3.2 exactly 7 modules in emit/llvm/ import llvm_emit_lowering.oo"
SHIM_IMPORTS=$(grep -l "llvm_emit_shims.oo" "$REPO_ROOT/emit/llvm/"*.oo 2>/dev/null | wc -l || true)
assert_eq "0" "$SHIM_IMPORTS" \
  "3.2 zero modules in emit/llvm/ import obsolete llvm_emit_shims.oo"

# 3.3: Genuine execution of llvm_emit_main_args lowering
OUT_3_3=$("$OODAC_BIN" emit-llvm "$SCRIPT_DIR/fixtures/challenger_llvm_args.oo" 2>&1)
RC_3_3=$?
assert_exit_code 0 $RC_3_3 \
  "3.3 challenger_llvm_args.oo compiles cleanly under emit-llvm"
assert_contains "call void @oo_slist_new(%OoSList* sret(%OoSList) %args.slot)" "$OUT_3_3" \
  "3.3 output contains genuine llvm_emit_main_args slist initialization"
assert_contains "args.args_loop:" "$OUT_3_3" \
  "3.3 output contains genuine llvm_emit_main_args argv parsing loop"

# 3.4: Empirically verify LLVM IR validity via llvm-as assembler
echo "$OUT_3_3" | llvm-as -o /dev/null 2>/dev/null
RC_3_4=$?
assert_exit_code 0 $RC_3_4 \
  "3.4 generated LLVM IR is semantically and syntactically valid (llvm-as passes)"

# ==============================================================================
# SECTION 4: C Backend & Inlined Secret Taint Module (c_emit_secret.oo)
# ==============================================================================
set_feature "C Backend & Secret Taint Inlining"

# 4.1: Excise verification of obsolete shims
assert_file_not_exists "$REPO_ROOT/emit/c/c_emit_meta.oo" \
  "4.1 c_emit_meta.oo excised"
assert_file_not_exists "$REPO_ROOT/emit/c/c_emit_meta_drive.oo" \
  "4.1 c_emit_meta_drive.oo excised"
assert_file_not_exists "$REPO_ROOT/emit/c/c_emit_secret_alias.oo" \
  "4.1 c_emit_secret_alias.oo excised"

# 4.2: Direct secret sink refusal
OUT_4_2=$("$OODAC_BIN" emit-c "$SCRIPT_DIR/fixtures/challenger_secret_direct.oo" 2>&1 || true)
assert_contains "sink refuse: println receives secret my_secret" "$OUT_4_2" \
  "4.2 direct secret sink refused with genuine diagnostic"

# 4.3: Inlined secret alias chain tracking and refusal
OUT_4_3=$("$OODAC_BIN" emit-c "$SCRIPT_DIR/fixtures/challenger_secret_alias.oo" 2>&1 || true)
assert_contains "println sink refuses SECRET my_alias" "$OUT_4_3" \
  "4.3 inlined alias tracker detects and refuses secret alias sink"

# 4.4: Dotted struct secret prefix taint tracking and refusal
OUT_4_4=$("$OODAC_BIN" emit-c "$SCRIPT_DIR/fixtures/challenger_secret_dotted.oo" 2>&1 || true)
assert_contains "println sink refuses SECRET p" "$OUT_4_4" \
  "4.4 dotted struct secret prefix taint detects and refuses tainted field sink"

# ==============================================================================
# SECTION 5: x86 Backend & Inlined SSA Emission (x86_emit.oo)
# ==============================================================================
set_feature "x86 Backend & SSA Inlining"

# 5.1: Excise verification of obsolete x86 shims
assert_file_not_exists "$REPO_ROOT/emit/x86/x86_emit_shims.oo" \
  "5.1 x86_emit_shims.oo excised"

# 5.2: Verify x86_emit_cap_test is completely absent
CAP_TEST_COUNT=$(grep -c "x86_emit_cap_test" "$REPO_ROOT/emit/x86/x86_emit.oo" 2>/dev/null || true)
assert_eq "0" "$CAP_TEST_COUNT" \
  "5.2 crude x86_emit_cap_test is absent from x86_emit.oo"

# 5.3: Fail closed on missing fn main
OUT_5_3=$("$OODAC_BIN" emit-x86 "$SCRIPT_DIR/fixtures/valid_minimal.oo" 2>&1 || true)
assert_contains "need fn main" "$OUT_5_3" \
  "5.3 x86 emitter fails closed when fn main is absent"

# 5.4: Genuine execution of x86 SSA compilation and runtime text inlining
OUT_5_4=$("$OODAC_BIN" emit-x86 "$SCRIPT_DIR/fixtures/challenger_aarch64_sample.oo" 2>&1)
RC_5_4=$?
assert_exit_code 0 $RC_5_4 \
  "5.4 x86 emitter compiles challenger sample cleanly"
assert_contains "push %rbp" "$OUT_5_4" \
  "5.4 output contains standard SysV AMD64 prologue"
assert_contains "list_push:" "$OUT_5_4" \
  "5.4 output contains inlined x86 runtime blob"

# 5.5: Empirically verify machine code assembly via GNU as
echo "$OUT_5_4" | as --64 -o /dev/null 2>/dev/null
RC_5_5=$?
assert_exit_code 0 $RC_5_5 \
  "5.5 generated x86 assembly compiles cleanly into machine code (as --64 passes)"

# ==============================================================================
# SECTION 6: Line Limits & Trailing Comma Compliance on Target Modules
# ==============================================================================
set_feature "Structural Integrity on Changed Modules"

# 6.1: Check line limits on normalized and inlined modules
LLVM_L=$(wc -l < "$REPO_ROOT/emit/llvm/llvm_emit_lowering.oo")
assert_le "$LLVM_L" 256 "6.1 llvm_emit_lowering.oo ($LLVM_L lines) <= 256"

A64_L=$(wc -l < "$REPO_ROOT/emit/aarch64/aarch64_entry_gate.oo")
assert_le "$A64_L" 256 "6.1 aarch64_entry_gate.oo ($A64_L lines) <= 256"

C_SEC_L=$(wc -l < "$REPO_ROOT/emit/c/c_emit_secret.oo")
assert_le "$C_SEC_L" 256 "6.1 c_emit_secret.oo ($C_SEC_L lines) <= 256"

X86_L=$(wc -l < "$REPO_ROOT/emit/x86/x86_emit.oo")
assert_le "$X86_L" 256 "6.1 x86_emit.oo ($X86_L lines) <= 256"

# 6.2: Check struct trailing commas
COMMA_CHECK=$(grep -E ',\s*\}' \
  "$REPO_ROOT/emit/llvm/llvm_emit_lowering.oo" \
  "$REPO_ROOT/emit/aarch64/aarch64_entry_gate.oo" \
  "$REPO_ROOT/emit/c/c_emit_secret.oo" \
  "$REPO_ROOT/emit/x86/x86_emit.oo" 2>/dev/null | wc -l)
assert_eq "0" "$COMMA_CHECK" \
  "6.2 zero struct trailing commas across normalized/inlined modules"

print_summary "Milestone 2 Empirical Challenger"
