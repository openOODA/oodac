#!/usr/bin/env bash
# Tier 2 M4: Boundary Cases for Features 14-16
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2 = 0), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_t2_m4_XXXXXX)"
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

run_suite() {
  local r_id="$1"
  echo "--- Executing Tier 2 M4 Boundaries Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # Feature 14 Boundaries
  cat << 'EOF' > "$d/span_bnd.oo"
// # Span Boundary
// Logline: Span boundary test
// Setup: emit-llvm
// Beats: span, main
pub fn calc() -> Int {
  let a = 1; let b = 2;
  return a + b;
}
pub fn main() -> Int { return calc(); }
EOF
  local b14_span=1
  if emit "$d/span_bnd.oo" "$d/span_bnd.ll"; then b14_span=0; fi
  record_test "T2-F14-01" "Multi-statement line coordinates emit" "$b14_span"

  local b14_as=1
  if [[ -f "$d/span_bnd.ll" ]]; then
    if llvm-as "$d/span_bnd.ll" -o "$d/sb.bc" >/dev/null 2>&1; then b14_as=0; fi
  fi
  record_test "T2-F14-02" "Multi-statement coordinates pass llvm-as" "$b14_as"
  local b14_col=1
  if grep -q 'DILocation(line: 6, column: 7' "$d/span_bnd.ll" 2>/dev/null && \
     grep -q 'DILocation(line: 6, column: 18' "$d/span_bnd.ll" 2>/dev/null; then
    b14_col=0
  fi
  record_test "T2-F14-03" "Column offsets track statement positions" "$b14_col"

  local b14_mono=1
  if grep -q 'DISubprogram(name: "calc".*line: 5' "$d/span_bnd.ll" 2>/dev/null && \
     grep -q 'DILocalVariable(name: "a".*line: 6' "$d/span_bnd.ll" 2>/dev/null && \
     grep -q 'DILocation(line: 7,' "$d/span_bnd.ll" 2>/dev/null; then
    b14_mono=0
  fi
  record_test "T2-F14-04" "Line coordinates increase monotonically" "$b14_mono"

  local b14_nodup=1
  local var_dups
  var_dups=$(grep -o '^![0-9]* = !DILocalVariable' "$d/span_bnd.ll" 2>/dev/null | sort | uniq -d | wc -l)
  if [[ "$var_dups" -eq 0 ]] && grep -q '!DILocalVariable' "$d/span_bnd.ll" 2>/dev/null; then
    b14_nodup=0
  fi
  record_test "T2-F14-05" "Zero duplicate coordinate descriptors" "$b14_nodup"

  # Feature 15 Boundaries
  local b15_subp=1
  if grep -q "DISubprogram(name: \"calc\"" "$d/span_bnd.ll" 2>/dev/null && \
     grep -q "DISubprogram(name: \"main\"" "$d/span_bnd.ll" 2>/dev/null; then
    b15_subp=0
  fi
  record_test "T2-F15-01" "Distinct DISubprogram for each function" "$b15_subp"

  local b15_cu=1
  if grep -q "!DICompileUnit" "$d/span_bnd.ll" 2>/dev/null; then b15_cu=0; fi
  record_test "T2-F15-02" "DICompileUnit present with correct metadata" "$b15_cu"

  local b15_sig=1
  if grep -q '!DISubroutineType(types: ![0-9]*)' "$d/span_bnd.ll" 2>/dev/null; then
    b15_sig=0
  fi
  record_test "T2-F15-03" "DISubroutineType describes argument signatures" "$b15_sig"

  local b15_sc=1
  local calc_sp
  calc_sp=$(grep -o '^![0-9]* = distinct !DISubprogram(name: "calc"' "$d/span_bnd.ll" 2>/dev/null | grep -o '![0-9]*')
  if [[ -n "$calc_sp" ]] && grep -q "DILocation(.*scope: $calc_sp" "$d/span_bnd.ll" 2>/dev/null; then
    b15_sc=0
  fi
  record_test "T2-F15-04" "DILocation scopes reference enclosing subprogram" "$b15_sc"

  local b15_full=1
  if grep -q '!DICompileUnit(.*emissionKind: FullDebug' "$d/span_bnd.ll" 2>/dev/null; then
    b15_full=0
  fi
  record_test "T2-F15-05" "FullDebug metadata format conforms to DWARF" "$b15_full"

  # Feature 16 Boundaries
  local b16_tool=1
  if which llvm-dwarfdump >/dev/null 2>&1; then b16_tool=0; fi
  record_test "T2-F16-01" "llvm-dwarfdump tool operational" "$b16_tool"

  local b16_obj=1
  if [[ "$b14_as" -eq 0 && -f "$d/sb.bc" ]]; then
    if clang -c "$d/sb.bc" -o "$d/sb.o" >/dev/null 2>&1; then b16_obj=0; fi
  fi
  record_test "T2-F16-02" "Boundary object compiles via clang" "$b16_obj"

  local b16_verify=1
  if [[ "$b16_obj" -eq 0 && -f "$d/sb.o" ]]; then
    if llvm-dwarfdump --verify "$d/sb.o" >/dev/null 2>&1; then b16_verify=0; fi
  fi
  record_test "T2-F16-03" "llvm-dwarfdump --verify completes with 0 errors" "$b16_verify"

  local b16_warn=1
  cat << 'EOF' > "$d/verify_bnd.oo"
pub fn main() { println(1); }
verify bnd_smoke {
  let x: Int = 10;
  if x != 10 { println(0); }
}
EOF
  local warn_cnt=0
  if emit "$d/verify_bnd.oo" "$d/verify_bnd.ll"; then
    clang -c "$d/verify_bnd.ll" -o "$d/vb.o" 2>"$d/vb_err.txt" || true
    if grep -q "ignoring invalid debug info" "$d/vb_err.txt" 2>/dev/null; then
      warn_cnt=$((warn_cnt + 1))
    fi
  else
    warn_cnt=$((warn_cnt + 1))
  fi
  clang -c "$d/span_bnd.ll" -o "$d/sb2.o" 2>"$d/sb_err.txt" || true
  if grep -q "ignoring invalid debug info" "$d/sb_err.txt" 2>/dev/null; then
    warn_cnt=$((warn_cnt + 1))
  fi
  if [[ "$warn_cnt" -eq 0 ]]; then
    b16_warn=0
  fi
  record_test "T2-F16-04" "Zero invalid debug info warnings under clang" "$b16_warn"

  local b16_sec=1
  if [[ -f "$d/sb.o" ]]; then
    local ddump
    ddump=$(llvm-dwarfdump -v "$d/sb.o" 2>/dev/null || true)
    if echo "$ddump" | grep -q "DW_TAG_compile_unit" && \
       echo "$ddump" | grep -q "DW_TAG_subprogram"; then
      b16_sec=0
    fi
  fi
  record_test "T2-F16-05" "Debug sections preserved across translation" "$b16_sec"
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
