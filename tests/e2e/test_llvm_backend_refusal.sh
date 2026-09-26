#!/usr/bin/env bash
# Tier 1: deferred/residual backend selection must fail closed with exact errors.
# CUDA has no backend (deferred); unknown names must not fall through to LLVM.
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_backend_refusal_XXXXXX)"
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

refusal_closed() {
  local id="$1" expected="$2" backend="$3" src="$4"
  local out="$TMPDIR/$id.out"
  if timeout 30s "$OODAC" build --backend "$backend" "$src" -o "$TMPDIR/$id.bin" >"$out" 2>&1; then
    record_test "$id" "residual backend $backend fails closed" 1
    return
  fi
  if grep -qF "$expected" "$out"; then
    record_test "$id" "residual backend $backend exact error" 0
  else
    record_test "$id" "residual backend $backend exact error" 1
  fi
}

run_suite() {
  local r_id="$1"
  echo "--- Executing backend-refusal suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  cat > "$d/ok.oo" << 'EOF'
pub fn main() {
    println("hi");
}
EOF

  refusal_closed "BEREF-01" "$(printf 'ERR\tbackend\tresidual: cuda')" "cuda" "$d/ok.oo"
  refusal_closed "BEREF-02" "$(printf 'ERR\tbuild\tbackend residual: c')" "c" "$d/ok.oo"
  refusal_closed "BEREF-03" "residual: bogus" "bogus" "$d/ok.oo"

  # Sanity: llvm backend still builds the same file.
  local lv=1
  if timeout 120s "$OODAC" build --backend llvm "$d/ok.oo" -o "$d/ok.bin" >/dev/null 2>&1; then
    if [[ "$("$d/ok.bin" 2>/dev/null)" == "hi" ]]; then
      lv=0
    fi
  fi
  record_test "BEREF-04" "llvm backend unaffected" "$lv"
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
echo "INFO: backend-refusal suite completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
