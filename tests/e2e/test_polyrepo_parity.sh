#!/usr/bin/env bash
# E2E Test Suite: Polyrepo Entrypoint LLVM Parity & C Deprecation
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2), Zero-Trust.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
if [[ -n "${PROJECT_ROOT:-}" ]]; then
  :
elif [[ -f "$SCRIPT_DIR/../../oodac/main.oo" ]]; then
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
fi
OODAC_DIR="$PROJECT_ROOT/oodac"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
if [[ ! -x "$OODAC" && -x "/tmp/oodac_pure_2460300/stage2_oodac" ]]; then
  OODAC="/tmp/oodac_pure_2460300/stage2_oodac"
fi

TMPDIR="$(mktemp -d /tmp/e2e_polyrepo_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

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
  echo "--- Executing Polyrepo Parity Suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. Polyrepo entrypoints check cleanly
  local entries=(
    "cli/main.oo"
    "ooda/main.oo"
    "opm/cli/main.oo"
    "lsp/cli/main.oo"
    "mcp/cli/main.oo"
    "bb/cli/main.oo"
  )
  for entry in "${entries[@]}"; do
    local tag="POLY-CHK-${entry%%/*}"
    local ep="$PROJECT_ROOT/$entry"
    local chk_st=1
    if [[ -f "$ep" ]]; then
      if timeout 120s "$OODAC" check "$ep" >/dev/null 2>&1; then
        chk_st=0
      fi
    fi
    record_test "$tag" "Typecheck $entry via LLVM compiler" "$chk_st"
  done

  # 2. LLVM IR emission parity for polyrepo entrypoints
  for entry in "${entries[@]}"; do
    local tag="POLY-LL-${entry%%/*}"
    local ep="$PROJECT_ROOT/$entry"
    local base="${entry%%/*}"
    local ll_st=1
    if [[ -f "$ep" ]]; then
      if timeout 120s "$OODAC" emit-llvm "$ep" > "$d/$base.ll" 2>&1; then
        if llvm-as "$d/$base.ll" -o "$d/$base.bc" >/dev/null 2>&1; then
          ll_st=0
        fi
      fi
    fi
    record_test "$tag" "emit-llvm and llvm-as for $entry" "$ll_st"
  done

  # 3. Residual C and GCC deprecation checks
  local c_res=0
  if timeout 5s "$OODAC" build --backend c "$PROJECT_ROOT/cli/main.oo" \
      -o "$d/fail.bin" >/dev/null 2>&1; then
    c_res=1
  fi
  record_test "DEPR-C-01" "Reject legacy --backend c on build" "$c_res"

  local gcc_res=0
  if timeout 5s "$OODAC" build --gcc "$PROJECT_ROOT/cli/main.oo" \
      -o "$d/fail.bin" >/dev/null 2>&1; then
    gcc_res=1
  fi
  record_test "DEPR-GCC-01" "Reject legacy --gcc flag on build" "$gcc_res"

  # 4. Zero residual emit-c in active polyrepo configurations
  local residual_c=0
  local makefiles
  makefiles=$(find "$PROJECT_ROOT" -maxdepth 2 -name "Makefile" 2>/dev/null)
  for mf in $makefiles; do
    if grep -q "emit-c" "$mf" 2>/dev/null; then
      residual_c=$((residual_c + 1))
    fi
  done
  record_test "DEPR-MAKE-01" "Zero emit-c in polyrepo Makefiles" "$residual_c"

  # 5. Per-repo VERSION tracking files exist and are non-empty
  local repos=("opm" "cli" "lsp" "mcp" "ooda")
  local missing_ver=0
  for repo in "${repos[@]}"; do
    local vf="$PROJECT_ROOT/$repo/VERSION"
    if [[ ! -s "$vf" ]]; then
      missing_ver=$((missing_ver + 1))
    fi
  done
  record_test "VER-PER-REPO" "All per-repo VERSION files populated" \
    "$missing_ver"

  # 6. CI workflow check: no ban on VERSION files
  local opm_ci="$PROJECT_ROOT/opm/.github/workflows/ci.yml"
  local ban_ci=0
  if [[ -f "$opm_ci" ]]; then
    if grep -q "test ! -e.*VERSION" "$opm_ci" 2>/dev/null; then
      ban_ci=1
    fi
  fi
  record_test "VER-CI-UNBAN" "opm CI has no ban on VERSION file" "$ban_ci"
}

run_suite 1
p1=$PASS_COUNT; f1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
p2=$PASS_COUNT; f2=$FAIL_COUNT

echo "=== Polyrepo Parity Determinism: R1 Pass=$p1 Fail=$f1 | R2 Pass=$p2 Fail=$f2 ==="
if [[ "$p1" -ne "$p2" || "$f1" -ne "$f2" ]]; then
  echo "CRITICAL: Non-deterministic execution between Run 1 and Run 2!" >&2
  exit 1
fi

echo "INFO: Polyrepo Parity Suite completed. Pass: $p1, Fail: $f1"
exit 0
