#!/usr/bin/env bash
# Test Suite: C-ABI Aggregate Returns & Niche Pointers
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC_BIN="${OODAC_BIN:-$PROJECT_ROOT/bin/oodac}"

TMPDIR="$(mktemp -d /tmp/test_abi_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

FIXTURE="$PROJECT_ROOT/oodac/tests/fixtures/test_abi_aggregates.oo"
LL_OUT="$TMPDIR/abi.ll"

# 1. Type Check & IR Emission
"$OODAC_BIN" check "$FIXTURE"
"$OODAC_BIN" emit-llvm "$FIXTURE" > "$LL_OUT"

# 2. Structural IR Assertions
grep -q "define hidden void @make_opt(ptr noalias sret(%OoOpt_St_MyStruct) align 8 %ret" "$LL_OUT"
grep -q "define hidden void @make_res(ptr noalias sret(%OoRes_St_MyStruct) align 8 %ret" "$LL_OUT"
grep -q "define hidden ptr @sovereign_opt_ref(" "$LL_OUT"
grep -q "define hidden ptr @sovereign_res_ref(" "$LL_OUT"
grep -q "define default void @exported_opt_ref(ptr noalias sret(%OoOpt_Ptr) align 8 %ret" "$LL_OUT"

# 3. Execution Verification
cd "$PROJECT_ROOT" && ./bin/ooda run "$FIXTURE" >/dev/null
echo "T-AGG-01: C-ABI Aggregates and Niche Pointers [PASS]"
