#!/usr/bin/env bash
# Tier 1: nested struct field access where the middle struct holds a
# struct-typed field BEFORE the accessed field. The rich-kind body must keep
# nested commas mapped so the GEP index counts real fields only.
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_struct_nested_XXXXXX)"
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
  echo "--- Executing struct-nested suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Nested read: struct-typed field sits before the accessed Int field.
  cat > "$d/nested.oo" << 'EOF'
pub type Caps = struct { r: Bool, w: Bool };
pub type Role = struct { name: String, caps: Caps, fuel: Int };
pub type Cell = struct { id: Int, role: Role };
pub fn main() {
    let c = Cell { id: 1, role: Role { name: "w", caps: Caps { r: true, w: false }, fuel: 500 } };
    println(c.role.name);
    println(c.role.fuel);
}
EOF

  local n_ok=1
  if timeout 30s "$OODAC" check "$d/nested.oo" >/dev/null 2>&1; then
    if timeout 30s "$OODAC" emit-llvm "$d/nested.oo" > "$d/nested.ll" 2>&1; then
      n_ok=0
    fi
  fi
  record_test "NEST-01" "nested field after struct field emits" "$n_ok"

  local n_as=1
  if [[ "$n_ok" -eq 0 ]] && llvm-as "$d/nested.ll" -o "$d/nested.bc" >/dev/null 2>&1; then
    n_as=0
  fi
  record_test "NEST-02" "nested IR assembles (valid GEP indices)" "$n_as"

  local n_run=1
  if timeout 120s "$OODAC" build --backend llvm "$d/nested.oo" -o "$d/nested.bin" >/dev/null 2>&1; then
    if [[ "$("$d/nested.bin" 2>/dev/null)" == "$(printf 'w\n500')" ]]; then
      n_run=0
    fi
  fi
  record_test "NEST-03" "nested binary prints w 500" "$n_run"

  # Ctor position: nested read as a constructor field value (swarm shape).
  cat > "$d/ctor.oo" << 'EOF'
pub type Caps = struct { r: Bool, w: Bool };
pub type Role = struct { name: String, caps: Caps, fuel: Int };
pub type Cell = struct { id: Int, role: Role, spare: Int };
pub type Snap = struct { id: Int, fuel: Int, who: String };
fn snap(c: Cell) -> Snap {
    return Snap { id: c.id, fuel: c.role.fuel, who: c.role.name };
}
pub fn main() {
    let c = Cell { id: 7, role: Role { name: "w", caps: Caps { r: true, w: false }, fuel: 500 }, spare: 0 };
    let s = snap(c);
    println(s.who);
    println(s.fuel);
}
EOF

  local c_ok=1
  if timeout 30s "$OODAC" check "$d/ctor.oo" >/dev/null 2>&1; then
    if timeout 30s "$OODAC" emit-llvm "$d/ctor.oo" > "$d/ctor.ll" 2>&1; then
      c_ok=0
    fi
  fi
  record_test "NEST-04" "ctor-position nested read emits" "$c_ok"

  local c_as=1
  if [[ "$c_ok" -eq 0 ]] && llvm-as "$d/ctor.ll" -o "$d/ctor.bc" >/dev/null 2>&1; then
    c_as=0
  fi
  record_test "NEST-05" "ctor IR assembles (valid GEP indices)" "$c_as"

  local c_run=1
  if timeout 120s "$OODAC" build --backend llvm "$d/ctor.oo" -o "$d/ctor.bin" >/dev/null 2>&1; then
    if [[ "$("$d/ctor.bin" 2>/dev/null)" == "$(printf 'w\n500')" ]]; then
      c_run=0
    fi
  fi
  record_test "NEST-06" "ctor binary prints w 500" "$c_run"
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
echo "INFO: struct-nested suite completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
