#!/usr/bin/env bash
# Tier 1: struct field-store retains (ARC). A field stored from a local must
# stay live after the local dies (e.g. across a return + later allocations).
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_arc_field_XXXXXX)"
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
  echo "--- Executing arc-field suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  cat > "$d/fstr.oo" << 'EOF'
// # arc field str repro
// Logline: x
// Setup: x
// Beats:
//   1. x
pub type Rec = struct { uri: String };
fn mk() -> Rec {
    let u: String = str_slice("xxblackbox/report_formatter.oo", 2, 30);
    let mut t: Rec = Rec { uri: "" };
    t.uri = u;
    return t;
}
pub fn main() {
    let t: Rec = mk();
    let junk: String = "aaaaaaaaaaaaaaaa" + "bbbbbbbbbbbbbbbb";
    let more: String = junk + junk + junk;
    println("uri=" + t.uri);
    println("more=" + chars_len(more).to_string());
}
EOF

  local fs=1
  if timeout 120s "$OODAC" build --backend llvm "$d/fstr.oo" -o "$d/fstr.bin" >/dev/null 2>&1; then
    if [[ "$("$d/fstr.bin" 2>/dev/null)" == "$(printf 'uri=blackbox/report_formatter.oo\nmore=96')" ]]; then
      fs=0
    fi
  fi
  record_test "ARCFIELD-01" "str field survives source scope + later allocs" "$fs"

  cat > "$d/flist.oo" << 'EOF'
// # arc field list repro
// Logline: x
// Setup: x
// Beats:
//   1. x
pub type Box = struct { items: List[String] };
fn mk2(tag: String) -> Box {
    let mut out: List[String] = list_new();
    out = list_push(out, tag);
    let mut b: Box = Box { items: list_new() };
    b.items = out;
    return b;
}
pub fn main() {
    let a: Box = mk2("first");
    let b: Box = mk2("second");
    let la: List[String] = a.items;
    let lb: List[String] = b.items;
    println("a=" + list_get(la, 0) + " b=" + list_get(lb, 0));
}
EOF

  local fl=1
  if timeout 120s "$OODAC" build --backend llvm "$d/flist.oo" -o "$d/flist.bin" >/dev/null 2>&1; then
    if [[ "$("$d/flist.bin" 2>/dev/null)" == "a=first b=second" ]]; then
      fl=0
    fi
  fi
  record_test "ARCFIELD-02" "list field survives across two calls" "$fl"
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
echo "INFO: arc-field suite completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
