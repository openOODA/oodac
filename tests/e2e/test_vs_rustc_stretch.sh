#!/usr/bin/env bash
# Stretch vs-rustc: 5 real-world-shaped pairs measured with the frozen method.
# Measurement ONLY: stdout bit-parity is enforced; ratios are reported, never gated.
# The frozen six (bootstrap/corpus/vs-rustc + test_vs_rustc.sh) are untouched.
# Invariants: wc -l <= 256, stdout bit-parity.
set -euo pipefail
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PAIR="$ROOT/bootstrap/corpus/vs-rustc-stretch"
WS="$(cd "$ROOT/.." && pwd)"
TMPDIR="$(mktemp -d /tmp/e2e_vs_rustc_stretch_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

export OODA_COMPILER="$OODAC" OODAC_BIN="$OODAC"
export OODA_FS_READDIR="${OODA_FS_READDIR:-$WS:/tmp:/usr:/etc}"
export OODA_FS_WRITEDIR="${OODA_FS_WRITEDIR:-$WS:/tmp}"
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-8589934592}"
export OODA_NO_JAIL=1
export OODA_OPT_LEVEL="${OODA_OPT_LEVEL:-3}"

NAMES="strbuild listxform nested errpath logscan"

echo "rustc $(rustc --version)"
echo "clang $(clang --version | head -1)"
echo "oodac $OODAC"

cd "$WS"
# Step 1: Compile and verify stdout parity for all 5 stretch pairs
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
  echo "PARITY-OK $n"
done

# Step 2: Interleaved pre-warmed runner (median-of-5, same method as frozen six)
ratios=""
for n in $NAMES; do
  obin="$TMPDIR/$n.oo.bin"
  rbin="$TMPDIR/$n.rs.bin"
  "$obin" >/dev/null
  "$rbin" >/dev/null
  res=$(python3 - <<PY "$obin" "$rbin"
import sys, time, subprocess, statistics
obin, rbin = sys.argv[1], sys.argv[2]
tos, trs = [], []
for _ in range(5):
    t0 = time.perf_counter(); subprocess.check_output([obin]); tos.append(time.perf_counter() - t0)
    t0 = time.perf_counter(); subprocess.check_output([rbin]); trs.append(time.perf_counter() - t0)
mo = statistics.median(tos)
mr = statistics.median(trs)
ratio = mo / mr if mr > 0 else 9.99
print(f"{mo:.8f} {mr:.8f} {ratio:.6f}")
PY
  )
  # shellcheck disable=SC2086
  read -r mo mr ratio <<< "$res"
  echo "stretch: $n oodac_med=$mo rustc_med=$mr ratio=$ratio"
  ratios="$ratios $ratio"
done

python3 - "$ratios" <<'PY'
import math, sys
vals = [float(x) for x in sys.argv[1].split() if x]
g = math.exp(sum(math.log(v) for v in vals) / len(vals))
print("stretch_geo_mean=%.4f n=%d (reported, NOT gated)" % (g, len(vals)))
PY
echo "VS_RUSTC_STRETCH_OK (parity 5/5, numbers reported)"
