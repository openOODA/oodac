#!/usr/bin/env bash
# Tier 1: Features 8-10 (MetricsCap LLVM Lowering, monotonic_us, 32-Ocap Linkage)
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OODAR_O="/home/jeryd/Projects/openOODA/oodar/build/oodar.o"
TMPDIR="$(mktemp -d /tmp/e2e_t1_r4_XXXXXX)"
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
  echo "--- Executing Tier 1 (Features 8-10) Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 8: MetricsCap LLVM Lowering
  cat << 'EOF' > "$d/mcap.oo"
pub fn use_m(m: &MetricsCap) -> Int { return 42; }
pub fn main(m: &MetricsCap) -> Int { return use_m(m); }
EOF
  # T1-F08-01: emit-llvm with MetricsCap parameter
  local f8_ok=1
  if timeout 5s "$OODAC" check "$d/mcap.oo" >/dev/null 2>&1; then
    if timeout 5s "$OODAC" emit-llvm "$d/mcap.oo" > "$d/mcap.ll" 2>&1; then
      if ! (grep -q "unknown type MetricsCap" "$d/mcap.ll" 2>/dev/null || false); then
        f8_ok=0
      fi
    fi
  fi
  record_test "T1-F08-01" "emit-llvm on MetricsCap parameter succeeds" "$f8_ok"

  # T1-F08-02: LLVM IR lowers MetricsCap parameter to i64
  local f8_i64=1
  if [[ -f "$d/mcap.ll" && "$f8_ok" -eq 0 ]]; then
    if grep -q "i64" "$d/mcap.ll" 2>/dev/null; then
      f8_i64=0
    fi
  fi
  record_test "T1-F08-02" "LLVM IR lowers MetricsCap to i64" "$f8_i64"

  # T1-F08-03: MetricsCap grant lowering produces @oo_cap_grant_metrics
  local f8_grant=1
  if [[ -f "$d/mcap.ll" && "$f8_ok" -eq 0 ]]; then
    if grep -q "@oo_cap_grant_metrics" "$d/mcap.ll" 2>/dev/null; then
      f8_grant=0
    fi
  fi
  record_test "T1-F08-03" "MetricsCap grant lowers to @oo_cap_grant_metrics" "$f8_grant"

  # T1-F08-04: clang compiles generated MetricsCap LLVM IR
  local f8_clang=1
  if [[ -f "$d/mcap.ll" && "$f8_ok" -eq 0 ]]; then
    if clang -c "$d/mcap.ll" -o "$d/mcap.o" >/dev/null 2>&1; then
      f8_clang=0
    fi
  fi
  record_test "T1-F08-04" "clang compiles generated MetricsCap LLVM IR" "$f8_clang"

  # T1-F08-05: Unknown capability fails closed
  cat << 'EOF' > "$d/bad_cap.oo"
pub fn bad(c: &BogusFakeCap) -> Int { return 0; }
pub fn main(c: &BogusFakeCap) -> Int { return bad(c); }
EOF
  local f8_bad=1
  if timeout 5s "$OODAC" check "$d/bad_cap.oo" >/dev/null 2>&1; then
    if ! timeout 5s "$OODAC" emit-llvm "$d/bad_cap.oo" >/dev/null 2>&1; then
      f8_bad=0
    fi
  fi
  record_test "T1-F08-05" "Unknown capability fails closed on emit-llvm" "$f8_bad"

  # Feature 9: monotonic_us Lowering Parity
  cat << 'EOF' > "$d/mono.oo"
pub fn main(t: &TimeCap) -> Int {
    let x: Int = monotonic_us(t);
    return x;
}
EOF
  local f9_ll=1
  if timeout 5s "$OODAC" check "$d/mono.oo" >/dev/null 2>&1; then
    if timeout 5s "$OODAC" emit-llvm "$d/mono.oo" > "$d/mono.ll" 2>&1; then
      f9_ll=0
    fi
  fi

  # T1-F09-01: LLVM runtime declaration has 0 arguments
  local f9_decl=1
  if [[ "$f9_ll" -eq 0 && -f "$d/mono.ll" ]]; then
    if grep -F -q "declare i64 @oo_monotonic_us()" "$d/mono.ll" 2>/dev/null; then
      f9_decl=0
    fi
  fi
  record_test "T1-F09-01" "LLVM declares @oo_monotonic_us() with 0 arguments" "$f9_decl"

  # T1-F09-02: LLVM call site passes 0 arguments
  local f9_call=1
  if [[ "$f9_ll" -eq 0 && -f "$d/mono.ll" ]]; then
    if grep -F -q "call i64 @oo_monotonic_us()" "$d/mono.ll" 2>/dev/null; then
      f9_call=0
    fi
  fi
  record_test "T1-F09-02" "LLVM call site calls @oo_monotonic_us() with 0 args" "$f9_call"

  # T1-F09-03: emit-c is residual
  local f9_c=1
  if ! timeout 5s "$OODAC" emit-c "$d/mono.oo" > "$d/mono.c" 2>&1; then
    f9_c=0
  fi
  record_test "T1-F09-03" "emit-c residual after C backend removal" "$f9_c"

  # T1-F09-04: Object linking with oodar.o
  local f9_link=1
  if [[ "$f9_ll" -eq 0 && -f "$d/mono.ll" ]]; then
    if clang -c "$d/mono.ll" -o "$d/mono.o" >/dev/null 2>&1; then
      if clang "$d/mono.o" "$OODAR_O" -lm -o "$d/mono.bin" >/dev/null 2>&1; then
        f9_link=0
      fi
    fi
  fi
  record_test "T1-F09-04" "LLVM-emitted monotonic_us links against oodar.o" "$f9_link"

  # T1-F09-05: Runtime execution returns positive timestamp
  local f9_run=1
  if timeout 90s "$OODAC" build "$d/mono.oo" -o "$d/mono_c.bin" >/dev/null 2>&1; then
    if "$d/mono_c.bin" >/dev/null 2>&1; then
      f9_run=0
    fi
  fi
  record_test "T1-F09-05" "monotonic_us() executes and returns timestamp" "$f9_run"

  # Feature 10: 32-Ocap Symbol Linkage
  # T1-F10-01: All 26 active capabilities present in oodar.o
  local nm_symbols
  nm_symbols=$(nm -g "$OODAR_O" 2>/dev/null || true)
  local active_caps=(
    "alloc" "arena" "audio" "bind" "camera" "compiler_read" "env" "ffi"
    "frame" "fs" "fsread" "fswrite" "gpu" "hid" "metrics" "net"
    "process" "rand" "sign" "sys" "tcp" "thread" "time" "udp" "usb" "window"
  )
  local missing_caps=0
  for cap in "${active_caps[@]}"; do
    if ! echo "$nm_symbols" | grep -F -q "oo_cap_grant_$cap"; then
      missing_caps=$((missing_caps + 1))
    fi
  done
  record_test "T1-F10-01" "All 26 capability grant symbols present in oodar.o" "$missing_caps"

  # T1-F10-02: sleep_ms lowering verification
  cat << 'EOF' > "$d/sleep.oo"
pub fn main(t: &TimeCap) -> Int {
    sleep_ms(t, 1);
    return 0;
}
EOF
  local f10_sleep=1
  if timeout 5s "$OODAC" check "$d/sleep.oo" >/dev/null 2>&1; then
    if timeout 5s "$OODAC" emit-llvm "$d/sleep.oo" > "$d/sleep.ll" 2>&1; then
      if grep -F -q "@oo_sleep_ms" "$d/sleep.ll" 2>/dev/null; then
        f10_sleep=0
      fi
    fi
  fi
  record_test "T1-F10-02" "sleep_ms lowers to @oo_sleep_ms in LLVM" "$f10_sleep"

  # T1-F10-03: now_ms lowering verification
  cat << 'EOF' > "$d/now.oo"
pub fn main(t: &TimeCap) -> Int {
    let ms: Int = now_ms(t);
    return ms;
}
EOF
  local f10_now=1
  if timeout 5s "$OODAC" check "$d/now.oo" >/dev/null 2>&1; then
    if timeout 5s "$OODAC" emit-llvm "$d/now.oo" > "$d/now.ll" 2>&1; then
      if grep -F -q "@oo_now_ms" "$d/now.ll" 2>/dev/null; then
        f10_now=0
      fi
    fi
  fi
  record_test "T1-F10-03" "now_ms lowers to @oo_now_ms in LLVM" "$f10_now"

  # T1-F10-04: oo_env_get lowering verification
  cat << 'EOF' > "$d/env.oo"
import "std/fs/process/env.oo";
pub fn main(e: &EnvCap) -> Int {
    let v: Result[String, String] = env_get(e, "HOME");
    match v { Ok(s) => { return 0; }, Err(e) => { return 1; } }
}
EOF
  local f10_env=1
  if timeout 5s "$OODAC" check "$d/env.oo" >/dev/null 2>&1; then
    if timeout 5s "$OODAC" emit-llvm "$d/env.oo" > "$d/env.ll" 2>&1; then
      if grep -F -q "@oo_env_get" "$d/env.ll" 2>/dev/null; then
        f10_env=0
      fi
    fi
  fi
  record_test "T1-F10-04" "env_get lowers to @oo_env_get in LLVM" "$f10_env"

  # T1-F10-05: Multi-capability compilation and execution
  cat << 'EOF' > "$d/multi_cap.oo"
pub fn main(p: &ProcessCap, e: &EnvCap, t: &TimeCap) -> Int {
    let now: Int = now_ms(t);
    if now > 0 { return 0; } return 1;
}
EOF
  local f10_multi=1
  if timeout 90s "$OODAC" build --backend llvm "$d/multi_cap.oo" -o "$d/multi_cap.bin" >/dev/null 2>&1; then
    if "$d/multi_cap.bin" >/dev/null 2>&1; then
      f10_multi=0
    fi
  fi
  record_test "T1-F10-05" "Multi-capability module compiles, links, and runs" "$f10_multi"
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
echo "INFO: Tier 1 Features 8-10 completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
