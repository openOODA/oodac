#!/usr/bin/env bash
# Tier 4: Real-World Application Scenarios
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t4_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"

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

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 4 Real-World Application Scenarios Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Scenario 1: Network Packet Protocol Decoder
  cat << 'EOF' > "$d/net_proto.oo"
// # Network Packet Protocol Decoder
// Logline: Decodes framed network packets with header and payload validation
// Setup: emit-llvm and llvm-as
// Beats: Packet struct, decode_frame, main
pub type Packet = struct { magic: Int, len: Int, status: Int };
pub fn decode_frame(magic: Int, len: Int) -> Option[Packet] {
  if magic != 4242 { return None; }
  if len > 1500 { return None; }
  return Some(Packet { magic: magic, len: len, status: 1 });
}
pub fn main() -> Int {
  let p = decode_frame(4242, 64);
  match p {
    Some(pkt) => { return pkt.status; }
    None => { return 0; }
  }
}
EOF
  local s1=1
  if emit "$d/net_proto.oo" "$d/net_proto.ll"; then
    if llvm-as "$d/net_proto.ll" -o "$d/net_proto.bc" >/dev/null 2>&1; then s1=0; fi
  fi
  record_test "T4-APP01" "Network Packet Protocol Decoder lowers and verifies" "$s1"

  # Scenario 2: Actor Concurrency Event Dispatcher
  cat << 'EOF' > "$d/actor_bus.oo"
// # Actor Concurrency Event Dispatcher
// Logline: Event bus routing with list mutation and pattern matching
// Setup: emit-llvm and llvm-as
// Beats: Event struct, dispatch, main
pub type Event = struct { topic: Int, val: Int };
pub fn dispatch(ev: Event) -> Int {
  if ev.topic == 0 { return ev.val; }
  if ev.topic == 1 { return ev.val * 2; }
  return 0;
}
pub fn main() -> Int {
  let e = Event { topic: 1, val: 50 };
  let empty: List[Event] = list_new();
  let queue = list_push(empty, e);
  let popped: Event = list_get(queue, 0);
  return dispatch(popped);
}
EOF
  local s2=1
  if emit "$d/actor_bus.oo" "$d/actor_bus.ll"; then
    if llvm-as "$d/actor_bus.ll" -o "$d/actor_bus.bc" >/dev/null 2>&1; then s2=0; fi
  fi
  record_test "T4-APP02" "Actor Concurrency Event Dispatcher lowers and verifies" "$s2"

  # Scenario 3: Formal Verification Secure Ledger
  cat << 'EOF' > "$d/ledger.oo"
// # Formal Verification Secure Ledger
// Logline: Verified ledger balance update with contract ensures
// Setup: emit-llvm and llvm-as
// Beats: Account struct, credit, main
pub type Account = struct { id: Int, balance: Int };
pub fn credit(acc: Account, amt: Int) -> Int
  ensures result >= amt
{
  return acc.balance + amt;
}
pub fn main() -> Int {
  let a = Account { id: 101, balance: 500 };
  return credit(a, 250);
}
EOF
  local s3=1
  if emit "$d/ledger.oo" "$d/ledger.ll"; then
    if llvm-as "$d/ledger.ll" -o "$d/ledger.bc" >/dev/null 2>&1; then s3=0; fi
  fi
  record_test "T4-APP03" "Formal Verification Secure Ledger lowers and verifies" "$s3"

  # Scenario 4: Cryptographic Token Verifier
  cat << 'EOF' > "$d/crypto_tok.oo"
// # Cryptographic Token Verifier
// Logline: Capability-gated cryptographic token validator
// Setup: emit-llvm and llvm-as
// Beats: Token struct, verify_token, main
pub type Token = struct { tag: Int, hash: Int };
pub fn verify_token(p: &ProcessCap, tok: Token) -> Int {
  let mask = 65535;
  let masked = tok.hash & mask;
  if masked == 1337 { return 1; }
  return 0;
}
pub fn main(p: &ProcessCap) -> Int {
  let t = Token { tag: 1, hash: 1337 };
  return verify_token(p, t);
}
EOF
  local s4=1
  if emit "$d/crypto_tok.oo" "$d/crypto_tok.ll"; then
    if llvm-as "$d/crypto_tok.ll" -o "$d/crypto_tok.bc" >/dev/null 2>&1; then s4=0; fi
  fi
  record_test "T4-APP04" "Cryptographic Token Verifier lowers and verifies" "$s4"

  # Scenario 5: Sensor Fusion Matrix Pipeline
  cat << 'EOF' > "$d/sensor_fusion.oo"
// # Sensor Fusion Matrix Pipeline
// Logline: Multi-sensor reading aggregation and filtering pipeline
// Setup: emit-llvm and llvm-as
// Beats: Sensor reading, filter, main
pub type Reading = struct { sensor_id: Int, raw_val: Int, valid: Bool };
pub fn filter_reading(r: Reading) -> Option[Int] {
  if !r.valid { return None; }
  let scaled = r.raw_val * 10 / 8;
  return Some(scaled);
}
pub fn main() -> Int {
  let r = Reading { sensor_id: 3, raw_val: 80, valid: true };
  let f = filter_reading(r);
  match f {
    Some(v) => { return v; }
    None => { return 0; }
  }
}
EOF
  local s5=1
  if emit "$d/sensor_fusion.oo" "$d/sensor_fusion.ll"; then
    if llvm-as "$d/sensor_fusion.ll" -o "$d/sensor_fusion.bc" >/dev/null 2>&1; then s5=0; fi
  fi
  record_test "T4-APP05" "Sensor Fusion Matrix Pipeline lowers and verifies" "$s5"
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
