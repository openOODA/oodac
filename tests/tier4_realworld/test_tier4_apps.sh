#!/usr/bin/env bash
# # test_tier4_apps.sh — Tier 4: Real-World Application Verification
#
# Logline: Executes static typechecking and semantic verification on all 5
#          production-grade real-world application scenarios.
#
# Beats:
#   1. Typecheck app_secure_vault.oo (Zero-trust key vault).
#   2. Typecheck app_crypto_pipeline.oo (Merkle tree pipeline).
#   3. Typecheck app_matrix_sensor_fusion.oo (Boyd E-M sensor engine).
#   4. Typecheck app_actor_event_bus.oo (Actor event router).
#   5. Typecheck app_compiler_plugin.oo (Compiler AST pass).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TESTS_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
OODA_BIN="${OODA_BIN:-$REPO_ROOT/bin/oodac}"

source "$TESTS_DIR/test_runner_core.sh"
set_feature "Tier 4 - Real-World Applications"

# Test 4.1: app_secure_vault.oo
OUT_4_1=$("$OODA_BIN" check "$SCRIPT_DIR/app_secure_vault.oo" 2>&1)
RC_4_1=$?
assert_exit_code 0 $RC_4_1 \
  "4.1 app_secure_vault.oo (Zero-Trust Key Vault) compiles cleanly"

# Test 4.2: app_crypto_pipeline.oo
OUT_4_2=$("$OODA_BIN" check "$SCRIPT_DIR/app_crypto_pipeline.oo" 2>&1)
RC_4_2=$?
assert_exit_code 0 $RC_4_2 \
  "4.2 app_crypto_pipeline.oo (Merkle Tree Pipeline) compiles cleanly"

# Test 4.3: app_matrix_sensor_fusion.oo
OUT_4_3=$("$OODA_BIN" check "$SCRIPT_DIR/app_matrix_sensor_fusion.oo" 2>&1)
RC_4_3=$?
assert_exit_code 0 $RC_4_3 \
  "4.3 app_matrix_sensor_fusion.oo (Boyd E-M Sensor Fusion) compiles cleanly"

# Test 4.4: app_actor_event_bus.oo
OUT_4_4=$("$OODA_BIN" check "$SCRIPT_DIR/app_actor_event_bus.oo" 2>&1)
RC_4_4=$?
assert_exit_code 0 $RC_4_4 \
  "4.4 app_actor_event_bus.oo (Actor Event Bus) compiles cleanly"

# Test 4.5: app_compiler_plugin.oo
OUT_4_5=$("$OODA_BIN" check "$SCRIPT_DIR/app_compiler_plugin.oo" 2>&1)
RC_4_5=$?
assert_exit_code 0 $RC_4_5 \
  "4.5 app_compiler_plugin.oo (Compiler AST Plugin Pass) compiles cleanly"
