#!/usr/bin/env bash
# Frozen 6-program vs-rustc: median of 3, geo-mean of (oodac/rustc) ≤ 1.00.
set -euo pipefail
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PAIR="$ROOT/bootstrap/corpus/vs-rustc"
WS="$(cd "$ROOT/.." && pwd)"
TMPDIR="$(mktemp -d /tmp/e2e_vs_rustc_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM
export OODA_COMPILER="$OODAC" OODAC_BIN="$OODAC"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$WS:/tmp:/usr:/etc}"
export OODA_FS_WRITEDIR="${OODA_FS_WRITEDIR:-$WS:/tmp}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-8589934592}"
export OODA_NO_JAIL=1
NAMES="add range list struct result concat"
median3() {
  python3 -c 'import sys; v=sorted(float(x) for x in sys.argv[1:]); print(v[1])' "$1" "$2" "$3"
}
echo "rustc $(rustc --version)"
echo "clang $(clang --version | head -1)"
echo "oodac $OODAC"
ratios=""
cd "$WS"
for n in $NAMES; do
  oo="$PAIR/$n.oo"
  rs="$PAIR/$n.rs"
  obin="$TMPDIR/$n.oo.bin"
  rbin="$TMPDIR/$n.rs.bin"
  "$OODAC" build "$oo" -o "$obin"
  rustc -C opt-level=3 -C lto=thin -C panic=abort "$rs" -o "$rbin"
  out_o=$("$obin")
  out_r=$("$rbin")
  if [[ "$out_o" != "$out_r" ]]; then
    echo "FAIL $n stdout oodac=$(printf %q "$out_o") rustc=$(printf %q "$out_r")"
    exit 1
  fi
  t_o=""
  t_r=""
  i=0
  while [[ $i -lt 3 ]]; do
    t_o="$t_o $(python3 -c 'import time,subprocess,sys; t=time.perf_counter(); subprocess.check_output(sys.argv[1]); print(time.perf_counter()-t)' "$obin")"
    t_r="$t_r $(python3 -c 'import time,subprocess,sys; t=time.perf_counter(); subprocess.check_output(sys.argv[1]); print(time.perf_counter()-t)' "$rbin")"
    i=$((i+1))
  done
  set -- $t_o
  mo=$(median3 "$1" "$2" "$3")
  set -- $t_r
  mr=$(median3 "$1" "$2" "$3")
  ratio=$(python3 -c "print($mo / $mr if $mr else 9.99)")
  echo "$n oodac_med=$mo rustc_med=$mr ratio=$ratio"
  ratios="$ratios $ratio"
done
python3 - "$ratios" <<'PY'
import math,sys
vals=[float(x) for x in sys.argv[1].split() if x]
g=math.exp(sum(math.log(v) for v in vals)/len(vals))
print("geo_mean=%.4f n=%d" % (g, len(vals)))
raise SystemExit(0 if g <= 1.00 else 1)
PY
echo VS_RUSTC_OK
