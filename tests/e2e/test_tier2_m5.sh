#!/usr/bin/env bash
# Tier 2 M5: Boundary Cases and E2E Execution for Features 17-19
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t2_m5_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS_COUNT=0; FAIL_COUNT=0
record_test() {
  local id="$1" desc="$2" status="$3"
  if [[ "$status" -eq 0 ]]; then
    echo "  [PASS] $id: $desc"; PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  [FAIL] $id: $desc"; FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}
emit() {
  local src="$1" out="$2"
  timeout 5s "$OODAC" check "$src" >/dev/null 2>&1
  timeout 5s "$OODAC" emit-llvm "$src" > "$out" 2>&1
}
record_run() {
  local id="$1" desc="$2" src="$3" ll="$4" bin="$5"
  local s=1
  if emit "$src" "$ll"; then
    if clang -O2 "$ll" -o "$bin" >/dev/null 2>&1 && "$bin"; then s=0; fi
  fi
  record_test "$id" "$desc" "$s"
}
record_as() {
  local id="$1" desc="$2" src="$3" ll="$4" bc="$5"
  local s=1
  if emit "$src" "$ll" && llvm-as "$ll" -o "$bc" >/dev/null 2>&1; then s=0; fi
  record_test "$id" "$desc" "$s"
}

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 2 M5 Boundaries Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # T2-F17-01: Intra-function Option[&Int] unwrap and read
  cat << 'EOF' > "$d/opt_read.oo"
// # Opt Read
// Logline: Option[&Int] read
// Setup: emit-llvm
// Beats: opt, main
pub fn get_val(o: Option[&Int]) -> Int {
  match o {
    Some(p) => { return *p; }
    None => { return -1; }
  }
}
pub fn main() -> Int {
  let x: Int = 42;
  let o = Some(&x);
  if get_val(o) != 42 { return 1; }
  return 0;
}
EOF
  record_run "T2-F17-01" "Option[&Int] unwrap executes" \
    "$d/opt_read.oo" "$d/opt_read.ll" "$d/opt_read_bin"

  # T2-F17-02: Intra-function Option[&Int] None branch
  cat << 'EOF' > "$d/opt_none.oo"
// # Opt None
// Logline: Option[&Int] None
// Setup: emit-llvm
// Beats: opt_none, main
pub fn get_val_or_default(o: Option[&Int], def: Int) -> Int {
  match o {
    Some(p) => { return *p; }
    None => { return def; }
  }
}
pub fn main() -> Int {
  let o: Option[&Int] = None;
  if get_val_or_default(o, 99) != 99 { return 1; }
  return 0;
}
EOF
  record_run "T2-F17-02" "Option[&Int] None branch executes" \
    "$d/opt_none.oo" "$d/opt_none.ll" "$d/opt_none_bin"

  # T2-F17-03: Option[&mut Int] write through reference
  cat << 'EOF' > "$d/opt_mut.oo"
// # Opt Mut Write
// Logline: Option[&mut Int] write
// Setup: emit-llvm
// Beats: opt_mut, main
pub fn mutate_if_some(o: Option[&mut Int], val: Int) {
  match o {
    Some(p) => { *p = val; }
    None => {}
  }
}
pub fn main() -> Int {
  let mut x: Int = 10;
  mutate_if_some(Some(&mut x), 50);
  if x != 50 { return 1; }
  return 0;
}
EOF
  record_run "T2-F17-03" "Option[&mut Int] mutation executes" \
    "$d/opt_mut.oo" "$d/opt_mut.ll" "$d/opt_mut_bin"

  # T2-F17-04: Result[&Int, Int] Ok branch unwrap and read
  cat << 'EOF' > "$d/res_ok.oo"
// # Res Ok
// Logline: Result[&Int, Int] Ok
// Setup: emit-llvm
// Beats: res_ok, main
pub fn unwrap_res(r: Result[&Int, Int]) -> Int {
  match r {
    Ok(p) => { return *p; }
    Err(_) => { return -1; }
  }
}
pub fn main() -> Int {
  let x: Int = 77;
  let r: Result[&Int, Int] = Ok(&x);
  if unwrap_res(r) != 77 { return 1; }
  return 0;
}
EOF
  record_run "T2-F17-04" "Result[&Int, Int] Ok unwrap executes" \
    "$d/res_ok.oo" "$d/res_ok.ll" "$d/res_ok_bin"

  # T2-F17-05: Result[&Int, Int] Err branch
  cat << 'EOF' > "$d/res_err.oo"
// # Res Err
// Logline: Result[&Int, Int] Err
// Setup: emit-llvm
// Beats: res_err, main
pub fn is_err(r: Result[&Int, Int]) -> Bool {
  match r {
    Ok(_) => { return false; }
    Err(_) => { return true; }
  }
}
pub fn main() -> Int {
  let r: Result[&Int, Int] = Err(99);
  if !is_err(r) { return 1; }
  return 0;
}
EOF
  record_run "T2-F17-05" "Result[&Int, Int] Err executes" \
    "$d/res_err.oo" "$d/res_err.ll" "$d/res_err_bin"

  # T2-F17-06: Chained pointer options
  cat << 'EOF' > "$d/opt_chain.oo"
// # Option Chain
// Logline: Option chaining
// Setup: emit-llvm
// Beats: chain, main
pub fn check_pos(p: &Int) -> Option[&Int] {
  if *p > 0 { return Some(p); }
  return None;
}
pub fn main() -> Int {
  let a: Int = 15;
  let b: Int = -5;
  match check_pos(&a) {
    Some(p) => { if *p != 15 { return 1; } }
    None => { return 2; }
  }
  match check_pos(&b) {
    Some(_) => { return 3; }
    None => {}
  }
  return 0;
}
EOF
  record_run "T2-F17-06" "Chained Option[&Int] executes" \
    "$d/opt_chain.oo" "$d/opt_chain.ll" "$d/opt_chain_bin"

  # Feature 18: C ABI Marshalling Boundaries
  cat << 'EOF' > "$d/str_bnd.oo"
// # String Boundary
// Logline: String boundaries
// Setup: emit-llvm
// Beats: str, main
pub fn empty_str() -> String { return ""; }
pub fn main() -> Int { return empty_str().len(); }
EOF
  record_as "T2-F18-01" "String boundary IR passes llvm-as" \
    "$d/str_bnd.oo" "$d/str_bnd.ll" "$d/sb.bc"

  local b18_types=1
  if [[ -f "$d/opt_read.ll" ]]; then
    if grep -q "%OoOpt_Ptr = type { i32, ptr }" "$d/opt_read.ll" && \
       grep -q "%OoRes_Ptr = type { i32, ptr }" "$d/opt_read.ll"; then
      b18_types=0
    fi
  fi
  record_test "T2-F18-02" "C ABI %OoOpt_Ptr and %OoRes_Ptr types verified" "$b18_types"

  # Feature 19: Capability Bitmasks Boundaries
  cat << 'EOF' > "$d/multi_cap.oo"
// # Multi Cap
// Logline: Multiple capabilities
// Setup: emit-llvm
// Beats: caps, main
pub fn multi_act(p: &ProcessCap, m: &MetricsCap) -> Int { return 42; }
pub fn main(p: &ProcessCap, m: &MetricsCap) -> Int { return multi_act(p, m); }
EOF
  local b19_caps=1
  if emit "$d/multi_cap.oo" "$d/multi_cap.ll"; then
    if grep -q "i64 noundef" "$d/multi_cap.ll" 2>/dev/null && \
       llvm-as "$d/multi_cap.ll" -o "$d/mc.bc" >/dev/null 2>&1; then
      b19_caps=0
    fi
  fi
  record_test "T2-F19-01" "Multiple capability parameters lower to scalar i64" "$b19_caps"

  cat << 'EOF' > "$d/cap_chain.oo"
// # Cap Chain
// Logline: Capability pass chain
// Setup: emit-llvm
// Beats: c1, c2, c3, main
pub fn c3(p: &ProcessCap) -> Int { return 7; }
pub fn c2(p: &ProcessCap) -> Int { return c3(p); }
pub fn c1(p: &ProcessCap) -> Int { return c2(p); }
pub fn main(p: &ProcessCap) -> Int { return c1(p); }
EOF
  local b19_chain=1
  if emit "$d/cap_chain.oo" "$d/cap_chain.ll"; then
    if grep -q "call i64 @c2" "$d/cap_chain.ll" 2>/dev/null && \
       grep -q "call i64 @c3" "$d/cap_chain.ll" 2>/dev/null && \
       llvm-as "$d/cap_chain.ll" -o "$d/cc.bc" >/dev/null 2>&1; then
      b19_chain=0
    fi
  fi
  record_test "T2-F19-02" "Capability chain passes via scalar registers" "$b19_chain"
}

# Double-run determinism protocol
run_suite 1; P1=$PASS_COUNT; F1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2; P2=$PASS_COUNT; F2=$FAIL_COUNT

if [[ "$P1" -ne "$P2" || "$F1" -ne "$F2" || "$F1" -ne 0 ]]; then
  echo "Determinism failure: Run1 ($P1/$F1) != Run2 ($P2/$F2)"
  exit 1
fi
echo "Deterministic PASS: $P1 tests passed in both runs."
exit 0
