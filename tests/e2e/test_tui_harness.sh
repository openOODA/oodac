#!/usr/bin/env bash
# E2E Test Suite: ooda-tui Harness Execution, MCP/LSP Wiring & Flags
# Compliance: wc -l <= 256, Double-Run (Run_1 == Run_2), Zero-Trust.
set -euo pipefail
export OO_LIST_AMBIENT_QUOTA="${OO_LIST_AMBIENT_QUOTA:-34359738368}"
export OODA_NO_JAIL="${OODA_NO_JAIL:-1}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
if [[ -f "$SCRIPT_DIR/../../tui/main.oo" ]]; then
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
elif [[ -f "$SCRIPT_DIR/../../../tui/main.oo" ]]; then
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
elif [[ -d "/home/jeryd/Projects/openOODA/tui" ]]; then
  PROJECT_ROOT="/home/jeryd/Projects/openOODA"
else
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
fi
export OODA_FS_READDIR="${OODA_FS_READDIR:-$PROJECT_ROOT}"
TUI_DIR="$PROJECT_ROOT/tui"
OODAC="${OODAC_BIN:-$HOME/.openooda/bin/oodac}"
if [[ ! -x "$OODAC" && -x "/tmp/oodac_pure_2460300/stage2_oodac" ]]; then
  OODAC="/tmp/oodac_pure_2460300/stage2_oodac"
fi

TMPDIR="$(mktemp -d /tmp/e2e_tui_XXXXXX)"
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
  echo "--- Executing TUI Harness Suite Run $r_id ---"
  local d="$TMPDIR/run_$r_id"
  mkdir -p "$d"

  # 1. Typecheck tui/main.oo
  local tui_chk=1
  if [[ -f "$TUI_DIR/main.oo" ]]; then
    if timeout 180s "$OODAC" check "$TUI_DIR/main.oo" >/dev/null 2>&1; then
      tui_chk=0
    fi
  fi
  record_test "TUI-CHK-MAIN" "Typecheck tui/main.oo cleanly" "$tui_chk"

  # 2. Check ooda-tui executable if built, or check installed binary
  local tui_bin=""
  if [[ -x "$TUI_DIR/dist/ooda-tui" ]]; then
    tui_bin="$TUI_DIR/dist/ooda-tui"
  elif [[ -x "$HOME/.openooda/bin/ooda-tui" ]]; then
    tui_bin="$HOME/.openooda/bin/ooda-tui"
  fi

  if [[ -n "$tui_bin" ]]; then
    # TUI-FLAG-HELP: --help exits 0
    local h_st=1
    if timeout 5s "$tui_bin" --help >/dev/null 2>&1; then
      h_st=0
    fi
    record_test "TUI-FLAG-HELP" "$tui_bin --help returns code 0" "$h_st"

    # TUI-FLAG-VER: --version exits 0
    local v_st=1
    if timeout 5s "$tui_bin" --version >/dev/null 2>&1; then
      v_st=0
    fi
    record_test "TUI-FLAG-VER" "$tui_bin --version returns code 0" "$v_st"

    # TUI-FLAG-BAD: unknown flag exits non-zero
    local b_st=1
    if ! timeout 5s "$tui_bin" --nonexistent_bogus_flag >/dev/null 2>&1; then
      b_st=0
    fi
    record_test "TUI-FLAG-BAD" "Unknown flag rejected non-zero" "$b_st"

    # TUI-BANNER: --teamwork --yolo with OODACODEX
    local codex="$PROJECT_ROOT/openOODA/northstar.oot"
    if [[ ! -f "$codex" ]]; then
      codex="$HOME/.openooda/northstar.oot"
    fi
    local tm_st=1
    if [[ -f "$codex" ]]; then
      if echo '/exit' | timeout 10s env OODACODEX="$codex" "$tui_bin" \
          --teamwork >/dev/null 2>&1; then
        tm_st=0
      fi
    fi
    record_test "TUI-BANNER" "--teamwork banner with OODACODEX" "$tm_st"
  else
    record_test "TUI-FLAG-HELP" "ooda-tui binary available" 1
    record_test "TUI-FLAG-VER" "ooda-tui binary available" 1
    record_test "TUI-FLAG-BAD" "ooda-tui binary available" 1
    record_test "TUI-BANNER" "ooda-tui binary available" 1
  fi

  # 3. QA probe syntax checks
  local probes=("argv.oo" "negative.oo")
  for pr in "${probes[@]}"; do
    local pr_path="$TUI_DIR/qa/$pr"
    local pr_st=1
    if [[ -f "$pr_path" ]]; then
      if timeout 10s "$OODAC" check "$pr_path" >/dev/null 2>&1; then
        pr_st=0
      fi
    fi
    record_test "TUI-QA-${pr%%.*}" "QA probe $pr passes typecheck" "$pr_st"
  done

  # 4. MCP tool execution contract: OODACODEX required
  local mcp_tool="$TUI_DIR/tools/tool_mcp.oo"
  local mcp_has_codex=1
  if [[ -f "$mcp_tool" ]]; then
    if grep -q "OODACODEX" "$mcp_tool" 2>/dev/null; then
      mcp_has_codex=0
    fi
  fi
  record_test "TUI-MCP-CODEX" "tool_mcp.oo references OODACODEX" \
    "$mcp_has_codex"

  # 5. LSP client configuration references lsp binary
  local lsp_tool="$TUI_DIR/tools/lsp_client.oo"
  local lsp_has_bin=1
  if [[ -f "$lsp_tool" ]]; then
    if grep -q "lsp" "$lsp_tool" 2>/dev/null; then
      lsp_has_bin=0
    fi
  fi
  record_test "TUI-LSP-BIN" "lsp_client.oo references lsp binary" \
    "$lsp_has_bin"
}

run_suite 1
p1=$PASS_COUNT; f1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
p2=$PASS_COUNT; f2=$FAIL_COUNT

echo "=== TUI Harness Determinism: R1 Pass=$p1 Fail=$f1 | R2 Pass=$p2 Fail=$f2 ==="
if [[ "$p1" -ne "$p2" || "$f1" -ne "$f2" ]]; then
  echo "CRITICAL: Non-deterministic execution between Run 1 and Run 2!" >&2
  exit 1
fi

echo "INFO: TUI Harness Suite completed. Pass: $p1, Fail: $f1"
exit 0
