#!/usr/bin/env bash
# # Differential C-vs-LLVM ratchet probe
# Why bash not .oo: drives the seed plus clang/gcc across backends and compares
# bytes (host-tooling exception, cf. bootstrap/oodac_pure_build).
# job: for each case, build with --backend llvm and --backend c, run each binary
# twice in fresh processes, require self-identical bytes, then compare backends.
# expect: ledger.txt pins the exact per-backend sha256 (or the refusal class).
# Any unlisted file must show parity; any unlisted divergence, stale pin,
# drift, tightening, or unpinned parity fails closed. The ledger only shrinks.
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
# The harness anchors cwd at WS_ROOT below; pin a relative seed first.
if [[ "$HOST" != /* ]]; then HOST="$(pwd)/$HOST"; fi
LEDGER="${LEDGER:-$SCRIPT_DIR/ledger.txt}"
OUTDIR="$ROOT/.ooda-cache/ooda-tmp/diff"
mkdir -p "$OUTDIR"
# oodar_root resolves oodar/oodar.c relative to cwd: anchor at the workspace root.
cd "$WS_ROOT"
BUILD_TO=280
RUN_TO=60

CASES=()
if [[ $# -gt 0 ]]; then
  CASES=("$@")
else
  while IFS= read -r f; do CASES+=("$f"); done < <(cd "$ROOT" && ls bootstrap/corpus/emit-llvm/pass/*.oo bootstrap/corpus/differential/cases/*.oo 2>/dev/null)
fi

run_bin() {  # <bin> <out> -> prints rc (nonzero exits and 124 timeouts are data, not errors)
  local bin="$1" out="$2" rc=0
  timeout "$RUN_TO" "$bin" >"$out" 2>"$out.err" || rc=$?
  echo "$rc"
}

fails=0
for rel in "${CASES[@]}"; do
  base="$(basename "$rel" .oo)"
  tag="$(echo "$rel" | tr '/' '_')"
  ll_bin="$OUTDIR/${tag}.llvm.bin" c_bin="$OUTDIR/${tag}.c.bin"
  ll_build_err="$OUTDIR/${tag}.llvm.berr" c_build_err="$OUTDIR/${tag}.c.berr"
  # wide scope in, single writedir out (cache_dir concatenates blindly).
  # Build failures are ledger data; keep them from tripping set -e.
  ll_brc=0
  env OODA_COMPILER="$HOST" OODAC_BIN="$HOST" OODA_FS_READDIR="$WS_ROOT:/tmp" \
    OODA_FS_WRITEDIR="$WS_ROOT" PATH=/usr/local/bin:/usr/bin:/bin \
    timeout "$BUILD_TO" "$HOST" build --backend llvm "$ROOT/$rel" -o "$ll_bin" >"$OUTDIR/${tag}.llvm.bout" 2>"$ll_build_err" || ll_brc=$?
  c_brc=0
  env OODA_COMPILER="$HOST" OODAC_BIN="$HOST" OODA_FS_READDIR="$WS_ROOT:/tmp" \
    OODA_FS_WRITEDIR="$WS_ROOT" PATH=/usr/local/bin:/usr/bin:/bin \
    timeout "$BUILD_TO" "$HOST" build --backend c "$ROOT/$rel" -o "$c_bin" >"$OUTDIR/${tag}.c.bout" 2>"$c_build_err" || c_brc=$?
  ll_cls="ok" c_cls="ok" ll_sha="-" c_sha="-" ll_rc="-" c_rc="-"
  if [[ $ll_brc -ne 0 ]]; then ll_cls="fail"; else
    ll_rc="$(run_bin "$ll_bin" "$OUTDIR/${tag}.llvm.out1")"
    ll_rc2="$(run_bin "$ll_bin" "$OUTDIR/${tag}.llvm.out2")"
    if [[ "$ll_rc" != "$ll_rc2" ]] || ! cmp -s "$OUTDIR/${tag}.llvm.out1" "$OUTDIR/${tag}.llvm.out2"; then
      echo "FAIL $rel nondeterministic-llvm rc=$ll_rc/$ll_rc2"; fails=$((fails+1)); continue
    fi
    ll_sha="$(sha256sum "$OUTDIR/${tag}.llvm.out1" | awk '{print substr($1,1,16)}')"
  fi
  if [[ $c_brc -ne 0 ]]; then c_cls="fail"; else
    c_rc="$(run_bin "$c_bin" "$OUTDIR/${tag}.c.out1")"
    c_rc2="$(run_bin "$c_bin" "$OUTDIR/${tag}.c.out2")"
    if [[ "$c_rc" != "$c_rc2" ]] || ! cmp -s "$OUTDIR/${tag}.c.out1" "$OUTDIR/${tag}.c.out2"; then
      echo "FAIL $rel nondeterministic-c rc=$c_rc/$c_rc2"; fails=$((fails+1)); continue
    fi
    c_sha="$(sha256sum "$OUTDIR/${tag}.c.out1" | awk '{print substr($1,1,16)}')"
  fi
  if [[ "$ll_cls" == "ok" && "$c_cls" == "ok" && "$ll_rc" == "$c_rc" ]]; then
    if cmp -s "$OUTDIR/${tag}.llvm.out1" "$OUTDIR/${tag}.c.out1"; then obs="parity $ll_sha $c_sha"
    else obs="diverge $ll_sha $c_sha"; fi
  elif [[ "$ll_cls" == "fail" && "$c_cls" == "fail" ]]; then obs="both-fail - -"
  elif [[ "$ll_cls" == "fail" ]]; then obs="llvm-fail - $c_sha"
  else obs="c-fail $ll_sha -"; fi
  # ledger lookup (exact relpath match, last word before # is reason text).
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
    if [[ "$want_cls" == "diverge" && "$got_cls" == "parity" ]]; then
      echo "FAIL $rel TIGHTEN: ledger says diverge but backends agree ($got_a); delete the ledger line"
    else
      echo "FAIL $rel class-change: ledger [$want_cls] observed [$obs]"
    fi
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
