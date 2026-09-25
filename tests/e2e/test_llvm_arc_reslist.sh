#!/usr/bin/env bash
# Tier 1: Result[List] payloads survive across calls (ARC resl/resil).
# A returned Ok(list) must stay live after a second call reuses the heap;
# the Err string side must not corrupt either.
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_arc_reslist_XXXXXX)"
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
  echo "--- Executing arc-reslist suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  cat > "$d/slist.oo" << 'EOF'
// # reslist slist repro
// Logline: x
// Setup: x
// Beats:
//   1. x
fn mk(tag: String) -> Result[List[String], String] {
    let mut out: List[String] = list_new();
    out = list_push(out, "R-" + tag);
    return Ok(out);
}
pub fn main() {
    let a: Result[List[String], String] = mk("a");
    let b: Result[List[String], String] = mk("b");
    let ra: List[String] = match a { Ok(r) => r, Err(_) => list_new() };
    let rb: List[String] = match b { Ok(r) => r, Err(_) => list_new() };
    println("ra={" + list_get(ra, 0) + "} rb={" + list_get(rb, 0) + "}");
}
EOF

  local sl=1
  if timeout 120s "$OODAC" build --backend llvm "$d/slist.oo" -o "$d/slist.bin" >/dev/null 2>&1; then
    if [[ "$("$d/slist.bin" 2>/dev/null)" == "ra={R-a} rb={R-b}" ]]; then
      sl=0
    fi
  fi
  record_test "RESLIST-01" "SList first result intact after second call" "$sl"

  cat > "$d/ilist.oo" << 'EOF'
// # reslist ilist repro
// Logline: x
// Setup: x
// Beats:
//   1. x
fn mk(tag: Int) -> Result[List[Int], String] {
    let mut out: List[Int] = list_new();
    out = list_push(out, tag);
    return Ok(out);
}
fn empty_i() -> List[Int] {
    let o: List[Int] = list_new();
    return o;
}
pub fn main() {
    let a: Result[List[Int], String] = mk(11);
    let b: Result[List[Int], String] = mk(22);
    let ra: List[Int] = match a { Ok(r) => r, Err(_) => empty_i() };
    let rb: List[Int] = match b { Ok(r) => r, Err(_) => empty_i() };
    println("ra=" + list_get(ra, 0).to_string() + " rb=" + list_get(rb, 0).to_string());
}
EOF

  local il=1
  if timeout 120s "$OODAC" build --backend llvm "$d/ilist.oo" -o "$d/ilist.bin" >/dev/null 2>&1; then
    if [[ "$("$d/ilist.bin" 2>/dev/null)" == "ra=11 rb=22" ]]; then
      il=0
    fi
  fi
  record_test "RESLIST-02" "IList first result intact after second call" "$il"

  cat > "$d/errside.oo" << 'EOF'
// # reslist err side
// Logline: x
// Setup: x
// Beats:
//   1. x
fn mk(fail: Bool) -> Result[List[String], String] {
    if fail { return Err("boom"); }
    let mut out: List[String] = list_new();
    out = list_push(out, "ok-row");
    return Ok(out);
}
pub fn main() {
    let a: Result[List[String], String] = mk(true);
    let b: Result[List[String], String] = mk(false);
    let ea: String = match a { Ok(_) => "unexpected", Err(e) => e };
    let rb: List[String] = match b { Ok(r) => r, Err(_) => list_new() };
    println("ea=" + ea + " rb=" + list_get(rb, 0));
}
EOF

  local es=1
  if timeout 120s "$OODAC" build --backend llvm "$d/errside.oo" -o "$d/errside.bin" >/dev/null 2>&1; then
    if [[ "$("$d/errside.bin" 2>/dev/null)" == "ea=boom rb=ok-row" ]]; then
      es=0
    fi
  fi
  record_test "RESLIST-03" "Err string side intact beside Ok list" "$es"
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
echo "INFO: arc-reslist suite completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
