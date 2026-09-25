#!/usr/bin/env bash
# Tier 1: --json-errors must terminate. cli_parse.oo once forgot i = i + 1
# on this flag, hanging every invocation at 100% CPU. Cases pin fast,
# valid-JSON behavior on good and bad files plus the --json alias.
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
TMPDIR="$(mktemp -d /tmp/e2e_json_errors_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OODA_FS_READDIR="${OODA_FS_READDIR:-$(cd "$PROJECT_ROOT/.." && pwd -P):$TMPDIR}"
export OODA_FS_WRITEDIR="${OODA_FS_WRITEDIR:-$(cd "$PROJECT_ROOT/.." && pwd -P):$TMPDIR}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"
export OODA_COMPILER="${OODA_COMPILER:-$OODAC}"

PASS_COUNT=0
FAIL_COUNT=0
RUN1=""
RUN2=""

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

cat > "$TMPDIR/good.oo" <<'EOF'
pub fn main() -> Result[Int, String] {
    println("json-errors-ok");
    return Ok(0);
}
EOF

cat > "$TMPDIR/bad.oo" <<'EOF'
pub fn main() -> Result[Int, String] {
    let x: Int = "not-an-int";
    return Ok(x);
}
EOF

run_once() {
  local out=""
  local st=1
  if out=$(timeout 60s "$OODAC" check --json-errors "$TMPDIR/good.oo" 2>&1); then
    st=0
  else
    st=$?
  fi
  if [[ "$st" -eq 0 && "$out" == "[]" ]]; then
    echo "  [PASS] JE-01: good file returns [] fast"
  else
    echo "  [FAIL] JE-01: good file st=$st out=$out"
  fi

  local bout="" bst=1
  if bout=$(timeout 60s "$OODAC" check --json-errors "$TMPDIR/bad.oo" 2>&1); then
    bst=0
  else
    bst=$?
  fi
  if [[ "$bst" -ne 0 && "$bout" == *'"code"'* ]]; then
    echo "  [PASS] JE-02: bad file fails closed with JSON"
  else
    echo "  [FAIL] JE-02: bad file bst=$bst bout=$bout"
  fi

  local aout="" ast=1
  if aout=$(timeout 60s "$OODAC" check --json "$TMPDIR/good.oo" 2>&1); then
    ast=0
  else
    ast=$?
  fi
  if [[ "$ast" -eq 0 && "$aout" == "[]" ]]; then
    echo "  [PASS] JE-03: --json alias returns [] fast"
  else
    echo "  [FAIL] JE-03: alias ast=$ast aout=$aout"
  fi
}

RUN1=$(run_once)
echo "$RUN1"
RUN2=$(run_once)

DET_LINE="  [PASS] JE-DET: Run1 == Run2"
if [[ "$RUN1" != "$RUN2" ]]; then
  DET_LINE="  [FAIL] JE-DET: Run1 != Run2"
  echo "--- Run1 ---"; echo "$RUN1"
  echo "--- Run2 ---"; echo "$RUN2"
fi
echo "$DET_LINE"

while IFS= read -r line; do
  case "$line" in
    *"[PASS]"*) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    *"[FAIL]"*) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
  esac
done <<< "$(printf '%s\n%s' "$RUN1" "$DET_LINE")"

echo "=== Determinism Result: Run1 Pass=$((PASS_COUNT)) Fail=$((FAIL_COUNT)) ==="
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo "INFO: json-errors suite completed. Pass: $PASS_COUNT, Fail: 0 (Run 1 == Run 2 verified)"
  exit 0
fi
echo "INFO: json-errors suite completed with failures."
exit 1
