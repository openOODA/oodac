#!/usr/bin/env bash
# Size + memory budgets for the smallest program (maintained probe).
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
#
# Canonical smallest program: bootstrap/corpus/emit-llvm/pass/fn_ret_int.oo.
# Per-piece budgets (bytes): emit-llvm --concat IR, linked ELF, `size` text.
# Memory budgets (kB max RSS via /usr/bin/time -v): whole `oodac build` and
# the exact clang link replay (cli/cli_build.oo non-shared argv). The replay
# must be bit-identical to `oodac build` output (fidelity gate M-05).
#
# Budgets re-baselined 2026-09-23 on oodac v0.5.0 + oodar v4.0.41
# liboodar-core.a (clang 22, Fedora x86_64; measured text=21000 ll=4190
# bin=32304 build_peak~=95152 link_peak~=95296). The prior 19456 figure is
# recorded nowhere in this tree.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WS="$(cd "$PROJECT_ROOT/.." && pwd)"
TMPDIR="$(mktemp -d /tmp/e2e_budgets_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OODA_FS_READDIR="${OODA_FS_READDIR:-$WS:/tmp:/usr:/etc}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-8589934592}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"

TEXT_BUDGET=22016
LL_BUDGET=8192
# 36 KiB: strip-debug anchor symtab (landlock ctor, blackbox trio) costs ~2 KiB
# over strip-all; still catches real bloat (full static oodar is MBs).
BIN_BUDGET=36864
BUILD_PEAK_BUDGET_KB=131072
LINK_PEAK_BUDGET_KB=131072

SMALL="$PROJECT_ROOT/bootstrap/corpus/emit-llvm/pass/fn_ret_int.oo"

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

resolve_oodar() {
  if [[ -f "$WS/oodar/oodar.c" ]]; then echo "$WS/oodar"; return 0; fi
  if [[ -f "$PROJECT_ROOT/../oodar/oodar.c" ]]; then echo "$PROJECT_ROOT/../oodar"; return 0; fi
  return 1
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Size/Memory Budgets Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"
  # Run-dir cache first (host_rt + IR land in $d); workspace + /tmp kept as
  # write fallbacks (check-phase artifact writes require them).
  export OODA_FS_WRITEDIR="$d:$WS:/tmp"

  # M-00: measurement tooling present (fail closed, no silent skip)
  local m00=1
  if [[ -x /usr/bin/time ]] && command -v size >/dev/null 2>&1; then m00=0; fi
  record_test "M-00" "Measurement tools /usr/bin/time and size present" "$m00"

  # M-01: whole-build peak RSS within budget
  local m01=1 bpeak=0
  if [[ "$m00" -eq 0 ]] && /usr/bin/time -v timeout 60s "$OODAC" build "$SMALL" -o "$d/small.bin" >"$d/build.log" 2>"$d/build.time"; then
    bpeak=$(awk '/Maximum resident set size/ {print $6}' "$d/build.time")
    if [[ "${bpeak:-0}" -le "$BUILD_PEAK_BUDGET_KB" ]]; then m01=0; fi
  fi
  record_test "M-01" "Build peak ${bpeak:-0} <= $BUILD_PEAK_BUDGET_KB kB" "$m01"

  # M-02: emit-llvm IR piece within budget
  local m02=1 llb=0
  if timeout 30s "$OODAC" emit-llvm --concat "$SMALL" >"$d/small.ll" 2>"$d/emit.log"; then
    llb=$(wc -c < "$d/small.ll")
    if [[ "$llb" -le "$LL_BUDGET" ]]; then m02=0; fi
  fi
  record_test "M-02" "LL piece $llb <= $LL_BUDGET bytes" "$m02"

  # M-03/M-04: linked ELF piece + text within budget
  local m03=1 m04=1 binb=0 textb=0
  if [[ -f "$d/small.bin" ]]; then
    binb=$(wc -c < "$d/small.bin")
    textb=$(size "$d/small.bin" | awk 'NR==2 {print $1}')
    if [[ "$binb" -le "$BIN_BUDGET" ]]; then m03=0; fi
    if [[ "$textb" -le "$TEXT_BUDGET" ]]; then m04=0; fi
  fi
  record_test "M-03" "ELF piece $binb <= $BIN_BUDGET bytes" "$m03"
  record_test "M-04" "ELF text $textb <= $TEXT_BUDGET bytes" "$m04"

  # M-05/M-06: faithful link replay (bit-identical) + link peak within budget
  local m05=1 m06=1 lpeak=0
  local od lib hr
  if od=$(resolve_oodar) && [[ -f "$od/scripts/lib/liboodar-core.a" ]]; then
    lib="$od/scripts/lib/liboodar-core.a"
    hr="$d/.ooda-cache/ooda-tmp/oodac_host_rt.c"
    if [[ -f "$hr" && -f "$d/small.ll" ]]; then
      printf '%s\n' "$d/small.ll" > "$d/link.rsp"
      if /usr/bin/time -v clang --no-default-config -Os -g0 -fno-ident \
        -ffunction-sections -fdata-sections -fno-asynchronous-unwind-tables \
        -fno-unwind-tables -Wno-override-module -I"$od" "$hr" @"$d/link.rsp" \
        "$lib" -Wl,-u,oo_blackbox_trap_cap -frandom-seed=0 -Wl,--build-id=none -Wl,--gc-sections \
        -Wl,-z,noseparate-code -Wl,--strip-debug -lm -ldl -lpthread \
        -o "$d/replay.bin" >"$d/link.log" 2>"$d/link.time"; then
        lpeak=$(awk '/Maximum resident set size/ {print $6}' "$d/link.time")
        if cmp -s "$d/replay.bin" "$d/small.bin"; then m05=0; fi
        if [[ "${lpeak:-0}" -le "$LINK_PEAK_BUDGET_KB" ]]; then m06=0; fi
      fi
    fi
  fi
  record_test "M-05" "Link replay bit-identical to oodac build" "$m05"
  record_test "M-06" "Link peak ${lpeak:-0} <= $LINK_PEAK_BUDGET_KB kB" "$m06"

  # M-07: replay binary runs with expected output
  local m07=1
  if [[ -f "$d/replay.bin" ]]; then
    if [[ "$("$d/replay.bin")" == "42" ]]; then m07=0; fi
  fi
  record_test "M-07" "Replay binary prints 42" "$m07"
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
echo "INFO: Size/memory budgets completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
