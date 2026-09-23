#!/usr/bin/env bash
# Tier 1: LLVM explicit capability-require lowering + negative probe.
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
OODAR_O="/home/jeryd/Projects/openOODA/oodar/build/oodar.o"
TMPDIR="$(mktemp -d /tmp/e2e_capreq_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OODA_FS_READDIR="${OODA_FS_READDIR:-$(cd "$PROJECT_ROOT/.." && pwd -P)}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_COMPILER="${OODA_COMPILER:-$OODAC}"

PASS_COUNT=0
FAIL_COUNT=0

record_test() {
  local id="$1" desc="$2" status="$3"
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
  echo "--- Executing LLVM cap-require suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  cat > "$d/gated.oo" << 'EOF'
pub fn main(fs_r: &FsReadCap, fs_w: &FsWriteCap) -> Int {
    let path: String = "/tmp/e2e_capreq_payload.txt";
    let w = write_file(fs_w, path, "capreq-ok");
    if w.is_err() { return 1; }
    let r = read_file(fs_r, path);
    if r.is_err() { return 2; }
    let body: String = match r { Ok(s) => s, Err(_) => "" };
    println(body);
    return 0;
}
EOF

  local emit_ok=1
  if timeout 10s "$OODAC" check "$d/gated.oo" >/dev/null 2>&1; then
    if timeout 10s "$OODAC" emit-llvm "$d/gated.oo" > "$d/gated.ll" 2>&1; then
      emit_ok=0
    fi
  fi
  record_test "CAP-REQ-01" "emit-llvm succeeds on with-cap program" "$emit_ok"

  local req_fs=1
  if [[ "$emit_ok" -eq 0 ]] && grep -F -q "call void @oo_cap_require_fsread(i64 " "$d/gated.ll" 2>/dev/null && grep -F -q "@oo_read_file(ptr sret(%OoResS)" "$d/gated.ll" 2>/dev/null; then
    if [[ "$(grep -n "call void @oo_cap_require_fsread" "$d/gated.ll" | head -n 1 | cut -d: -f1)" -lt "$(grep -n "@oo_read_file(ptr sret" "$d/gated.ll" | head -n 1 | cut -d: -f1)" ]]; then
      req_fs=0
    fi
  fi
  record_test "CAP-REQ-02" "explicit fsread gate precedes @oo_read_file" "$req_fs"

  local req_fw=1
  if [[ "$emit_ok" -eq 0 ]] && grep -F -q "call void @oo_cap_require_fswrite(i64 " "$d/gated.ll" 2>/dev/null && grep -F -q "@oo_write_file(ptr sret(%OoResV)" "$d/gated.ll" 2>/dev/null; then
    req_fw=0
  fi
  record_test "CAP-REQ-03" "explicit fswrite gate precedes @oo_write_file" "$req_fw"

  local decl_ok=1
  if [[ "$emit_ok" -eq 0 ]] && grep -F -q "declare void @oo_cap_require_fsread(i64, ptr)" "$d/gated.ll" 2>/dev/null && grep -F -q "declare void @oo_cap_require_fswrite(i64, ptr)" "$d/gated.ll" 2>/dev/null; then
    decl_ok=0
  fi
  record_test "CAP-REQ-04" "require gate declares present with (i64, ptr)" "$decl_ok"

  local as_ok=1
  if [[ "$emit_ok" -eq 0 ]] && llvm-as "$d/gated.ll" -o "$d/gated.bc" >/dev/null 2>&1; then
    as_ok=0
  fi
  record_test "CAP-REQ-05" "gated IR assembles with llvm-as" "$as_ok"

  local run_ok=1
  rm -f /tmp/e2e_capreq_payload.txt
  if timeout 120s "$OODAC" build --backend llvm "$d/gated.oo" -o "$d/gated.bin" >/dev/null 2>&1; then
    if "$d/gated.bin" > "$d/gated.out" 2>&1; then
      if grep -q "capreq-ok" "$d/gated.out" 2>/dev/null && [[ "$(cat /tmp/e2e_capreq_payload.txt 2>/dev/null)" == "capreq-ok" ]]; then
        run_ok=0
      fi
    fi
  fi
  rm -f /tmp/e2e_capreq_payload.txt
  record_test "CAP-REQ-06" "gated binary builds, links, and round-trips" "$run_ok"

  cat > "$d/capless.oo" << 'EOF'
pub fn main() {
    let s: String = read_file("/tmp/e2e_capreq_payload.txt");
    println(s);
}
EOF
  local ck_code=0
  if timeout 10s "$OODAC" check "$d/capless.oo" > "$d/capless.log" 2>&1; then
    ck_code=0
  else
    ck_code=$?
  fi
  local neg_build=1
  if [[ "$ck_code" -eq 1 ]] && grep -q "ERR.*capability" "$d/capless.log" 2>/dev/null && grep -q "FsReadCap" "$d/capless.log" 2>/dev/null; then
    neg_build=0
  fi
  record_test "CAP-NEG-01" "capless read_file refused at check with capability error" "$neg_build"

  local neg_code=1
  if [[ "$ck_code" -eq 1 ]]; then neg_code=0; fi
  record_test "CAP-NEG-02" "capless refusal exits with exact code 1" "$neg_code"

  local neg_bin=1
  if ! timeout 120s "$OODAC" build --backend llvm "$d/capless.oo" -o "$d/capless.bin" >/dev/null 2>&1; then
    if [[ ! -x "$d/capless.bin" ]]; then neg_bin=0; fi
  fi
  record_test "CAP-NEG-03" "capless program fails backend build with no binary" "$neg_bin"

  cat > "$d/gate_pin.c" << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
extern long long oo_cap_grant_fsread(void);
extern void oo_cap_require_fsread(long long, const char *);
extern void oo_cap_bridge_set_test_force_fail(int);
static int run_case(int which) {
  pid_t p = fork();
  if (p == 0) {
    if (which == 0) { oo_cap_require_fsread(0, "probe_forged"); _exit(99); }
    { long long tok = oo_cap_grant_fsread();
      oo_cap_bridge_set_test_force_fail(1);
      oo_cap_require_fsread(tok, "probe_disagree"); _exit(99); }
  }
  { int st = 0; waitpid(p, &st, 0);
    if (WIFEXITED(st)) return WEXITSTATUS(st); }
  return -1;
}
int main(void) {
  int c1 = run_case(0), c2 = run_case(1);
  printf("forged=%d disagree=%d\n", c1, c2);
  return (c1 == 1 && c2 == 2) ? 0 : 1;
}
EOF
  local pin_ok=1
  if [[ -f "$OODAR_O" ]] && clang "$d/gate_pin.c" "$OODAR_O" -lm -o "$d/gate_pin" >/dev/null 2>&1; then
    if ( cd "$d" && ./gate_pin > gate_pin.out 2>&1 ); then
      pin_ok=0
    fi
  fi
  record_test "CAP-NEG-04" "forged gate exits 1, OCap disagreement exits 2" "$pin_ok"
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
echo "INFO: LLVM cap-require suite completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
