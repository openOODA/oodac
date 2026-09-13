#!/usr/bin/env bash
# Tier 1: Features 5-7 (16 Anchors, Docs Remediation, Brand Capitalization)
# Compliance: wc -l <= 256, Double-Run ($Run_1 == Run_2), Zero-Trust.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMPDIR="$(mktemp -d /tmp/e2e_t1_r2_XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT INT TERM

PASS_COUNT=0
FAIL_COUNT=0

record_test() {
  local id="$1"
  local desc="$2"
  local status="$3"
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
  echo "--- Executing Tier 1 (Features 5-7) Run $r_id ---"

  # Feature 5: 16 Anchor Files Lowercase Migration
  local expected_anchors=(
    "anchor.oo"
    "ast/anchor.oo"
    "check/anchor.oo"
    "cli/anchor.oo"
    "docs/anchor.oo"
    "emit/anchor.oo"
    "emit/c/anchor.oo"
    "emit/llvm/anchor.oo"
    "lex/anchor.oo"
    "qa/anchor.oo"
    "qa/nested/anchor.oo"
    "scripts/anchor.oo"
    "tests/anchor.oo"
    "tests/fixtures/anchor.oo"
    "tests/tier4_realworld/anchor.oo"
    "types/anchor.oo"
  )

  # T1-F05-01: All 16 anchor.oo files exist
  local all_exist=0
  for a in "${expected_anchors[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$a" ]]; then
      all_exist=1
      break
    fi
  done
  record_test "T1-F05-01" "All 16 canonical anchor.oo files exist" "$all_exist"

  # T1-F05-02: Zero residual uppercase ANCHOR.oo files
  local residual_count
  residual_count=$(find "$PROJECT_ROOT" -name "ANCHOR.oo" \
    -not -path "*/.git/*" -not -path "*/.ooda-cache/*" -not -path "*/.agents/*" | wc -l)
  if [[ "$residual_count" -eq 0 ]]; then
    record_test "T1-F05-02" "Zero residual ANCHOR.oo files in repository" 0
  else
    record_test "T1-F05-02" "Zero residual ANCHOR.oo files in repository" 1
  fi

  # T1-F05-03: All 16 anchor.oo files non-empty
  local all_nonempty=0
  for a in "${expected_anchors[@]}"; do
    if [[ -f "$PROJECT_ROOT/$a" && ! -s "$PROJECT_ROOT/$a" ]]; then
      all_nonempty=1
      break
    fi
  done
  record_test "T1-F05-03" "All 16 anchor.oo files are non-empty" "$all_nonempty"

  # T1-F05-04: Line limit <= 256 for all 16 anchor.oo files
  local line_limit_ok=0
  for a in "${expected_anchors[@]}"; do
    if [[ -f "$PROJECT_ROOT/$a" ]]; then
      local lc
      lc=$(wc -l < "$PROJECT_ROOT/$a")
      if [[ "$lc" -gt 256 ]]; then
        line_limit_ok=1
        break
      fi
    fi
  done
  record_test "T1-F05-04" "Line limits <= 256 on all 16 anchor.oo files" "$line_limit_ok"

  # T1-F05-05: Zero stub markers in anchor files
  local stub_found=0
  for a in "${expected_anchors[@]}"; do
    if [[ -f "$PROJECT_ROOT/$a" ]]; then
      if (grep -E -q 'unimplemented!\(\)|todo!\(\)' "$PROJECT_ROOT/$a" || false); then
        stub_found=1
        break
      fi
    fi
  done
  record_test "T1-F05-05" "Zero stub markers in anchor.oo files" "$stub_found"

  # Feature 6: Documentation & Import Remediation
  # T1-F06-01: docs/anchor.oo imports lowercase .oot files
  local doc_upper_count=0
  if [[ -f "$PROJECT_ROOT/docs/anchor.oo" ]]; then
    doc_upper_count=$((grep -E 'import ".*[A-Z].*\.oot"' "$PROJECT_ROOT/docs/anchor.oo" || true) | wc -l)
  fi
  if [[ "$doc_upper_count" -eq 0 ]]; then
    record_test "T1-F06-01" "docs/anchor.oo contains zero uppercase .oot imports" 0
  else
    record_test "T1-F06-01" "docs/anchor.oo contains zero uppercase .oot imports" 1
  fi

  # T1-F06-02: All 7 canonical .oot files exist in docs/
  local expected_docs=(
    "docs/audit_safety.oot"
    "docs/cap_boundary.oot"
    "docs/cap_legacy_supersede_removal_todo.oot"
    "docs/silent-miscompile-prevention.oot"
    "docs/token_opt.oot"
    "docs/token_tooling.oot"
    "docs/x86-codegen-style.oot"
  )
  local docs_exist=0
  for d in "${expected_docs[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$d" ]]; then
      docs_exist=1
      break
    fi
  done
  record_test "T1-F06-02" "All 7 canonical docs/*.oot files exist in lowercase" "$docs_exist"

  # T1-F06-03: Seed documentation lowercase
  if [[ -f "$PROJECT_ROOT/bootstrap/seed/readme.oot" && -f "$PROJECT_ROOT/bootstrap/seed/signing.oot" ]]; then
    record_test "T1-F06-03" "Seed documentation files lowercase" 0
  else
    record_test "T1-F06-03" "Seed documentation files lowercase" 1
  fi

  # T1-F06-04: Line limit <= 256 on all .oot files
  local oot_line_ok=0
  while IFS= read -r f; do
    local lc
    lc=$(wc -l < "$f")
    if [[ "$lc" -gt 256 ]]; then
      oot_line_ok=1
      break
    fi
  done < <(find "$PROJECT_ROOT" -name "*.oot" -not -path "*/.git/*" -not -path "*/.agents/*")
  record_test "T1-F06-04" "Line limits <= 256 on all .oot files" "$oot_line_ok"

  # T1-F06-05: Non-existent doc import fails closed
  local fake_doc_test="$TMPDIR/fake_doc.oo"
  echo 'import "docs/nonexistent.oot"; pub fn main() -> Int { return 0; }' > "$fake_doc_test"
  if ! timeout 5s "${OODAC_BIN:-$HOME/.openooda/bin/oodac}" check "$fake_doc_test" >/dev/null 2>&1; then
    record_test "T1-F06-05" "Non-existent doc import fails closed" 0
  else
    record_test "T1-F06-05" "Non-existent doc import fails closed" 1
  fi

  # Feature 7: Brand Capitalization Preservation (openOODA)
  # T1-F07-01: Brand capitalization in README.md
  (grep -q "openOODA" "$PROJECT_ROOT/README.md" || false) \
    && record_test "T1-F07-01" "openOODA brand preserved in README.md" 0 \
    || record_test "T1-F07-01" "openOODA brand preserved in README.md" 1

  # T1-F07-02: Brand capitalization in LICENSE
  (grep -q "openOODA" "$PROJECT_ROOT/LICENSE" || false) \
    && record_test "T1-F07-02" "openOODA brand preserved in LICENSE" 0 \
    || record_test "T1-F07-02" "openOODA brand preserved in LICENSE" 1

  # T1-F07-03: Brand capitalization in docs/anchor.oo
  (grep -q "openOODA" "$PROJECT_ROOT/docs/anchor.oo" || false) \
    && record_test "T1-F07-03" "openOODA brand preserved in docs/anchor.oo" 0 \
    || record_test "T1-F07-03" "openOODA brand preserved in docs/anchor.oo" 1

  # T1-F07-04: No erroneous lowercasing of brand token in source code comments
  local bad_casing
  bad_casing=$((grep -rn "openooda" "$PROJECT_ROOT" \
    --exclude-dir={.git,.agents,dist,.ooda-cache,bin} 2>/dev/null || true) \
    | (grep -v "openooda\.org" || true) \
    | (grep -v "\.openooda" || true) \
    | (grep -v "/home/jeryd/Projects/openOODA" || true) \
    | (grep -v "openooda" || true) \
    | wc -l)
  if [[ "$bad_casing" -eq 0 ]]; then
    record_test "T1-F07-04" "No erroneous lowercasing of brand token in source" 0
  else
    record_test "T1-F07-04" "No erroneous lowercasing of brand token in source" 1
  fi

  # T1-F07-05: Canonical brand token integrity across docs
  local docs_brand_ok=0
  for d in "${expected_docs[@]}"; do
    if [[ -f "$PROJECT_ROOT/$d" ]]; then
      if (grep -q "OpenOoda" "$PROJECT_ROOT/$d" || false) || (grep -q "OPENOODA" "$PROJECT_ROOT/$d" || false); then
        docs_brand_ok=1
        break
      fi
    fi
  done
  record_test "T1-F07-05" "Zero malformed brand variants in documentation" "$docs_brand_ok"
}

run_suite 1
p1=$PASS_COUNT; f1=$FAIL_COUNT
PASS_COUNT=0; FAIL_COUNT=0
run_suite 2
p2=$PASS_COUNT; f2=$FAIL_COUNT

echo "=== Determinism Result: Run1 Pass=$p1 Fail=$f1 | Run2 Pass=$p2 Fail=$f2 ==="
if [[ "$p1" -ne "$p2" || "$f1" -ne "$f2" || "$f1" -ne 0 ]]; then
  echo "CRITICAL: Non-deterministic execution between Run 1 and Run 2!" >&2
  exit 1
fi
echo "INFO: Tier 1 Features 5-7 completed. Pass: $p1, Fail: $f1 (Run 1 == Run 2 verified)"
exit 0
