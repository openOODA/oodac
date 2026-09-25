#!/usr/bin/env bash
# Tier 1: struct field reads via params; struct names containing "Cap" must not
# be shadowed by capability detection (check uses suffix-match; emit must too).
# Covers the CapT minimal repro plus the multi-field owned/borrowed matrix.
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_struct_capname_XXXXXX)"
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
  echo "--- Executing struct-capname suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Minimal repro: 2-field struct named CapT, 2nd field via owned param.
  cat > "$d/min.oo" << 'EOF'
pub type CapT = struct { f0: String, f1: String };
fn j(c: CapT) -> String { return c.f1; }
pub fn main() {
    let c = CapT { f0: "a", f1: "b" };
    println(j(c));
}
EOF

  local min_ok=1
  if timeout 30s "$OODAC" check "$d/min.oo" >/dev/null 2>&1; then
    if timeout 30s "$OODAC" emit-llvm "$d/min.oo" > "$d/min.ll" 2>&1; then
      min_ok=0
    fi
  fi
  record_test "CAPNAME-01" "minimal CapT.f1-via-param emits" "$min_ok"

  local min_as=1
  if [[ "$min_ok" -eq 0 ]] && llvm-as "$d/min.ll" -o "$d/min.bc" >/dev/null 2>&1; then
    min_as=0
  fi
  record_test "CAPNAME-02" "minimal CapT IR assembles" "$min_as"

  local min_run=1
  if timeout 120s "$OODAC" build --backend llvm "$d/min.oo" -o "$d/min.bin" >/dev/null 2>&1; then
    if [[ "$("$d/min.bin" 2>/dev/null)" == "b" ]]; then
      min_run=0
    fi
  fi
  record_test "CAPNAME-03" "minimal CapT binary runs and prints b" "$min_run"

  # Matrix: CapT 1st/2nd fields, 3-field and Int 4-field structs, owned + borrowed.
  cat > "$d/matrix.oo" << 'EOF'
pub type CapT = struct { f0: String, f1: String };
pub type Trip = struct { a: String, b: String, c: String };
pub type Quad = struct { a: Int, b: Int, c: Int, d: Int };
fn cap0(c: CapT) -> String { return c.f0; }
fn cap1(c: CapT) -> String { return c.f1; }
fn capb0(c: &CapT) -> String { return c.f0; }
fn capb1(c: &CapT) -> String { return c.f1; }
fn ta(c: Trip) -> String { return c.a; }
fn tb(c: Trip) -> String { return c.b; }
fn tc(c: Trip) -> String { return c.c; }
fn tab(c: &Trip) -> String { return c.b; }
fn qd(c: &Quad) -> Int { return c.d; }
pub fn main() {
    let t = CapT { f0: "a", f1: "b" };
    println(cap0(t));
    println(cap1(t));
    println(capb0(&t));
    println(capb1(&t));
    let u = Trip { a: "x", b: "y", c: "z" };
    println(ta(u));
    println(tb(u));
    println(tc(u));
    println(tab(&u));
    let q = Quad { a: 1, b: 2, c: 3, d: 4 };
    println(qd(&q));
}
EOF

  local mx_ok=1
  if timeout 30s "$OODAC" check "$d/matrix.oo" >/dev/null 2>&1; then
    if timeout 30s "$OODAC" emit-llvm "$d/matrix.oo" > "$d/matrix.ll" 2>&1; then
      mx_ok=0
    fi
  fi
  record_test "CAPNAME-04" "owned+borrowed multi-field matrix emits" "$mx_ok"

  local mx_as=1
  if [[ "$mx_ok" -eq 0 ]] && llvm-as "$d/matrix.ll" -o "$d/matrix.bc" >/dev/null 2>&1; then
    mx_as=0
  fi
  record_test "CAPNAME-05" "matrix IR assembles" "$mx_as"

  local mx_run=1
  if timeout 120s "$OODAC" build --backend llvm "$d/matrix.oo" -o "$d/matrix.bin" >/dev/null 2>&1; then
    if [[ "$("$d/matrix.bin" 2>/dev/null)" == "$(printf 'a\nb\na\nb\nx\ny\nz\ny\n4')" ]]; then
      mx_run=0
    fi
  fi
  record_test "CAPNAME-06" "matrix binary prints all field values" "$mx_run"

  # Name edges: "Cap" as prefix (Capacity) and the exact name "Cap".
  cat > "$d/edges.oo" << 'EOF'
pub type Capacity = struct { f0: String, f1: String };
pub type Cap = struct { f0: String, f1: String };
fn e1(c: Capacity) -> String { return c.f1; }
fn e2(c: &Cap) -> String { return c.f1; }
pub fn main() {
    let a = Capacity { f0: "p", f1: "q" };
    println(e1(a));
    let b = Cap { f0: "r", f1: "s" };
    println(e2(&b));
}
EOF

  local ed_ok=1
  if timeout 30s "$OODAC" check "$d/edges.oo" >/dev/null 2>&1; then
    if timeout 30s "$OODAC" emit-llvm "$d/edges.oo" > "$d/edges.ll" 2>&1; then
      ed_ok=0
    fi
  fi
  record_test "CAPNAME-07" "Capacity/Cap name edges emit" "$ed_ok"

  local ed_run=1
  if [[ "$ed_ok" -eq 0 ]] && timeout 120s "$OODAC" build --backend llvm "$d/edges.oo" -o "$d/edges.bin" >/dev/null 2>&1; then
    if [[ "$("$d/edges.bin" 2>/dev/null)" == "$(printf 'q\ns')" ]]; then
      ed_run=0
    fi
  fi
  record_test "CAPNAME-08" "Capacity/Cap binary prints q s" "$ed_run"

  # Real capabilities still lower as i64 tokens with explicit require gates.
  cat > "$d/gated.oo" << 'EOF'
pub fn main(fs_r: &FsReadCap) -> Int {
    let r = read_file(fs_r, "/tmp/e2e_struct_capname_probe.txt");
    if r.is_err() { return 2; }
    return 0;
}
EOF

  local gate_ok=1
  if timeout 30s "$OODAC" check "$d/gated.oo" >/dev/null 2>&1; then
    if timeout 30s "$OODAC" emit-llvm "$d/gated.oo" > "$d/gated.ll" 2>&1; then
      if grep -F -q "call void @oo_cap_require_fsread(i64 " "$d/gated.ll" 2>/dev/null; then
        gate_ok=0
      fi
    fi
  fi
  record_test "CAPNAME-09" "real &FsReadCap still emits require gate" "$gate_ok"
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
echo "INFO: struct-capname suite completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
