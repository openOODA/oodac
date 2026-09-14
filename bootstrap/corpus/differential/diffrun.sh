#!/usr/bin/env bash
# # LLVM corpus ratchet probe
# Why bash not .oo: drives the seed plus clang across the emit-llvm corpus
# and compares stdout bytes (host-tooling exception, cf. bootstrap/oodac_pure_build).
# job: for each case, build with --backend llvm, run twice in fresh processes,
# require self-identical bytes, pin sha256 in ledger.txt.
# expect: ledger pins class + sha (parity means LLVM ran). C backend is gone.
# Any unlisted file, stale pin, drift, or class-change fails closed.
# in:  diffrun.sh <host-seed> [case...]
#      default cases: bootstrap/corpus/emit-llvm/pass/*.oo plus differential/cases/*.oo
#      LEDGER env overrides the ledger path (red-team testing only).
# out: one line per case plus suggested ledger lines for failures; exit 0 iff
#      every case resolves to its ledger expectation.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WS_ROOT="$(cd "$ROOT/.." && pwd)"
HOST="${1:?usage: diffrun.sh <host-seed> [case...]}"; shift || true
if [[ "$HOST" != /* ]]; then HOST="$(pwd)/$HOST"; fi
LEDGER="${LEDGER:-$SCRIPT_DIR/ledger.txt}"
OUTDIR="$ROOT/.ooda-cache/ooda-tmp/diff"
mkdir -p "$OUTDIR"
cd "$WS_ROOT"
BUILD_TO=280
RUN_TO=60

CASES=()
if [[ $# -gt 0 ]]; then
  CASES=("$@")
else
  while IFS= read -r f; do CASES+=("$f"); done < <(cd "$ROOT" && ls bootstrap/corpus/emit-llvm/pass/*.oo bootstrap/corpus/differential/cases/*.oo 2>/dev/null)
fi

run_bin() {
  local bin="$1" out="$2" rc=0
  timeout "$RUN_TO" "$bin" >"$out" 2>"$out.err" || rc=$?
  echo "$rc"
}

fails=0
for rel in "${CASES[@]}"; do
  tag="$(echo "$rel" | tr '/' '_')"
  ll_bin="$OUTDIR/${tag}.llvm.bin"
  ll_build_err="$OUTDIR/${tag}.llvm.berr"
  ll_brc=0
  env OODA_COMPILER="$HOST" OODAC_BIN="$HOST" OODA_FS_READDIR="$WS_ROOT:/tmp" \
    OODA_FS_WRITEDIR="$WS_ROOT" PATH=/usr/local/bin:/usr/bin:/bin \
    timeout "$BUILD_TO" "$HOST" build --backend llvm "$ROOT/$rel" -o "$ll_bin" >"$OUTDIR/${tag}.llvm.bout" 2>"$ll_build_err" || ll_brc=$?
  ll_cls="ok" ll_sha="-" ll_rc="-"
  if [[ $ll_brc -ne 0 ]]; then ll_cls="fail"; else
    ll_rc="$(run_bin "$ll_bin" "$OUTDIR/${tag}.llvm.out1")"
    ll_rc2="$(run_bin "$ll_bin" "$OUTDIR/${tag}.llvm.out2")"
    if [[ "$ll_rc" != "$ll_rc2" ]] || ! cmp -s "$OUTDIR/${tag}.llvm.out1" "$OUTDIR/${tag}.llvm.out2"; then
      echo "FAIL $rel nondeterministic-llvm rc=$ll_rc/$ll_rc2"; fails=$((fails+1)); continue
    fi
    ll_sha="$(sha256sum "$OUTDIR/${tag}.llvm.out1" | awk '{print substr($1,1,16)}')"
  fi
  if [[ "$ll_cls" == "ok" ]]; then obs="parity $ll_sha $ll_sha"
  else obs="llvm-fail - -"; fi
  entry="$(grep -E "^${rel//\//\\/} " "$LEDGER" 2>/dev/null || true)"
  if [[ -z "$entry" ]]; then
    echo "FAIL $rel unlisted: observed [$obs]"
    echo "  suggest: $rel $obs  # <reason>"
    fails=$((fails+1)); continue
  fi
  want_cls="$(echo "$entry" | awk '{print $2}')"
  want_a="$(echo "$entry" | awk '{print $3}')"
  want_b="$(echo "$entry" | awk '{print $4}')"
  got_cls="$(echo "$obs" | awk '{print $1}')"
  got_a="$(echo "$obs" | awk '{print $2}')"
  got_b="$(echo "$obs" | awk '{print $3}')"
  if [[ "$want_cls" != "$got_cls" ]]; then
    echo "FAIL $rel class-change: ledger [$want_cls] observed [$obs]"
    fails=$((fails+1)); continue
  fi
  if [[ "$want_a" != "$got_a" || "$want_b" != "$got_b" ]]; then
    echo "FAIL $rel drift: ledger [$want_a $want_b] observed [$got_a $got_b]"
    echo "  suggest: $rel $obs  # <reason>"
    fails=$((fails+1)); continue
  fi
  echo "ok $rel [$obs]"
done
echo "diffrun: fails=$fails cases=${#CASES[@]}"
exit "$([ "$fails" -eq 0 ] && echo 0 || echo 1)"
