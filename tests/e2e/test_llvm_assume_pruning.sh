#!/usr/bin/env bash
# Test Suite: LLVM Assume Optimization & Dead Branch Elimination under -O2 / -O3
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
OODAC_BIN="${OODAC_BIN:-$PROJECT_ROOT/bin/oodac}"

TMPDIR="$(mktemp -d /tmp/test_opt_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

FIXTURE="$PROJECT_ROOT/oodac/tests/fixtures/valid_contracts.oo"
LL_SRC="$TMPDIR/contracts.ll"

"$OODAC_BIN" check "$FIXTURE"
"$OODAC_BIN" emit-llvm "$FIXTURE" > "$LL_SRC"

# 1. Assert @llvm.assume emission and absence of dynamic traps
grep -q "call void @llvm.assume" "$LL_SRC"
! grep -q "@.con_" "$LL_SRC"
! grep -q "ctrap" "$LL_SRC"

# 2. Append downstream verification harness
cat << 'EOF' >> "$LL_SRC"
define i64 @test_assume_prune_pre(i64 %x) {
entry:
  %res = call i64 @safe_double(i64 %x)
  %c_dead = icmp slt i64 %x, 0
  br i1 %c_dead, label %dead_pre, label %alive_pre
dead_pre:
  ret i64 -999
alive_pre:
  ret i64 %res
}

define i64 @test_assume_prune_post(i64 %x) {
entry:
  %res = call i64 @safe_double(i64 %x)
  %c_dead = icmp slt i64 %res, %x
  br i1 %c_dead, label %dead_post, label %alive_post
dead_post:
  ret i64 -888
alive_post:
  ret i64 %res
}
EOF

# 3. Assert Dead Branch Pruning under opt -O2
opt -O2 -S "$LL_SRC" -o "$TMPDIR/opt_o2.ll"
! grep -q "dead_pre:" "$TMPDIR/opt_o2.ll"
! grep -q -- "-999" "$TMPDIR/opt_o2.ll"
! grep -q "dead_post:" "$TMPDIR/opt_o2.ll"
! grep -q -- "-888" "$TMPDIR/opt_o2.ll"
echo "T-OPT-01: opt -O2 dead branch pruning [PASS]"

# 4. Assert Dead Branch Pruning under opt -O3
opt -O3 -S "$LL_SRC" -o "$TMPDIR/opt_o3.ll"
! grep -q "dead_pre:" "$TMPDIR/opt_o3.ll"
! grep -q -- "-999" "$TMPDIR/opt_o3.ll"
! grep -q "dead_post:" "$TMPDIR/opt_o3.ll"
! grep -q -- "-888" "$TMPDIR/opt_o3.ll"
echo "T-OPT-02: opt -O3 dead branch pruning [PASS]"
