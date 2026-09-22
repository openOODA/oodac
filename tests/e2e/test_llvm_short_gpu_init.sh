#!/usr/bin/env bash
# Short gpu_init must lower to a declared @oo_gpu_init (need-scan normalization).
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
WS_ROOT="$(cd "$PROJECT_ROOT/.." && pwd -P)"
OODAC="${OODAC_BIN:-$PROJECT_ROOT/bin/oodac}"
LIBOODAR="$WS_ROOT/oodar/liboodar.a"
TMPDIR="$(mktemp -d /tmp/e2e_short_gpu_init_XXXXXX)"
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
  echo "--- Executing Short gpu_init Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"
  cat << 'EOF' > "$d/short_gpu_init.oo"
// # Short gpu_init declare probe
//
// Logline: Short gpu_init name must emit a declare for @oo_gpu_init.
//
// Setup: GpuCap token threaded to gpu_init. No hardware needed.
//
// Beats:
//   1. check accepts the short sealed gpu name.
//   2. emit-llvm declares @oo_gpu_init.

pub fn main(g: &GpuCap) {
    let rc: Int = gpu_init(g);
    println(rc);
}
EOF
  # G-SHORT-01: check accepts the short sealed gpu name
  local g_ck=1
  if timeout 30s "$OODAC" check "$d/short_gpu_init.oo" >/dev/null 2>&1; then
    g_ck=0
  fi
  record_test "G-SHORT-01" "check accepts short gpu_init sealed name" "$g_ck"

  # G-SHORT-02: emit-llvm succeeds after check
  local g_ll=1
  if [[ "$g_ck" -eq 0 ]]; then
    if timeout 30s "$OODAC" emit-llvm "$d/short_gpu_init.oo" > "$d/short_gpu_init.ll" 2>&1; then
      g_ll=0
    fi
  fi
  record_test "G-SHORT-02" "emit-llvm succeeds on short gpu_init" "$g_ll"

  # G-SHORT-03: call site lowers to @oo_gpu_init
  local g_call=1
  if [[ "$g_ll" -eq 0 ]]; then
    if grep -F -q "call i32 @oo_gpu_init(i64" "$d/short_gpu_init.ll" 2>/dev/null; then
      g_call=0
    fi
  fi
  record_test "G-SHORT-03" "call site lowers to @oo_gpu_init" "$g_call"

  # G-SHORT-04: referenced declare is emitted (pre-fix: omitted, clang errors)
  local g_decl=1
  if [[ "$g_ll" -eq 0 ]]; then
    if grep -F -q "declare i32 @oo_gpu_init(i64)" "$d/short_gpu_init.ll" 2>/dev/null; then
      g_decl=0
    fi
  fi
  record_test "G-SHORT-04" "emit-llvm declares @oo_gpu_init" "$g_decl"

  # G-SHORT-05: clang links the IR against liboodar.a (no GPU run)
  local g_link=1
  if [[ "$g_decl" -eq 0 && -f "$LIBOODAR" ]]; then
    if clang -O2 "$d/short_gpu_init.ll" "$LIBOODAR" -lm -lpthread -o "$d/short_gpu_init.bin" >/dev/null 2>&1; then
      g_link=0
    fi
  fi
  record_test "G-SHORT-05" "clang links short-gpu_init IR with liboodar.a" "$g_link"
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
echo "INFO: Short gpu_init probe completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
