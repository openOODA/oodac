# Original User Request

## Initial Request — 2026-09-12T18:46:41Z

Use a very large team of agents.

Remediate, verify, bootstrap-certify, and unify `oodac` (the openOODA native self-hosting compiler) with the polyrepo ecosystem. Transition all canonical `ANCHOR.oo` files to lowercase `anchor.oo`, resolve all path sensitivities in QA probes with anti-vacuity protection, complete LLVM backend intrinsics and 32-Ocap alignment, and certify byte-identical bootstrap fixed-point ($S_1 \equiv S_2$) and dual-run test suite determinism ($Run_1 \equiv Run_2 = 0$).

Working directory: /home/jeryd/Projects/openOODA/oodac
Integrity mode: development

## Requirements

### R1. Compiler Engine Lowercase Anchor Resolution
Ensure the compiler's AST loader (`ast/load_import_parse.oo`), module typechecker (`check/check_mod.oo`), unused import checker (`check/tc_unused_import.oo`), C emitter (`cli/cli_emit.oo`), LLVM emitter (`cli/cli_emit_llvm.oo`), and pure build script (`bootstrap/oodac_pure_build`) natively resolve `anchor.oo` with backward-compatible fallback to `ANCHOR.oo`.

### R2. Canonical File & Import Migration
Migrate all 16 `ANCHOR.oo` files and documentation `.oot` files in `oodac` to lowercase per RULES §1.19 (`anchor.oo`, `docs/audit_safety.oot`, `docs/cap_boundary.oot`, etc.). Update all import declarations across `oodac` and polyrepo root `openOODA/anchor.oo` without breaking any dependencies.

### R3. QA Test Harness Normalization & Anti-Vacuity Gate
Normalize all QA probes in `qa/` to resolve paths dynamically whether invoked from `oodac/` or polyrepo root (`openOODA/`). Implement strict anti-vacuity assertions across all probes so test cases fail closed if fixtures are missing, rather than passing accidentally on missing-file error messages. Clean up temporary test binaries and artifacts on exit.

### R4. LLVM Backend Parity & 32-Ocap Alignment
Implement LLVM lowering for intrinsics (`sleep_ms`, `now_ms`, `monotonic_us`, `oo_env_get`, and `MetricsCap`) in `emit/llvm/ll_builtin.oo`, `emit/llvm/ll_builtin_host.oo`, `emit/llvm/ll_rt.oo`, and `emit/llvm/ll_ty.oo` to guarantee full behavioral parity with the C backend across all standard library operations.

### R5. Self-Host Bootstrap & Dual-Run Certification
Successfully compile and link the self-hosted compiler via `bootstrap/oodac_pure_build`. Prove bit-for-bit cryptographic fixed-point convergence ($S_1 \equiv S_2$). Prove zero-defect double-run determinism ($Run_1 \equiv Run_2 = 0$) across all 13 probes in `qa/suite.oo` and the universal polyrepo suite `openOODA/qa/polyrepo_suite.oo`. Adhere strictly to the 256-line maximum limit (`wc -l <= 256`) on all `.oo` and `.oot` files.

## Acceptance Criteria

### Canonical File & Import Integrity
- [ ] All 16 `anchor.oo` files and `.oot` documentation files in `oodac` migrated to lowercase with zero residual `ANCHOR.oo` files
- [ ] Brand capitalization `openOODA` strictly preserved
- [ ] All import statements across `oodac` and `openOODA/anchor.oo` resolve cleanly with zero broken paths

### Governance & Line Limits
- [ ] Every created or modified `.oo` / `.oot` file strictly complies with the <= 256 lines ceiling (`wc -l <= 256`)
- [ ] Zero compiler warnings or type check regressions in the 243-module self-hosted codebase

### QA Probes & Anti-Vacuity Invariant
- [ ] All 13 probes in `qa/suite.oo` execute without path errors regardless of invocation CWD (`oodac/` vs polyrepo root)
- [ ] Negative test probes (`probe_smt_false_kind.oo`, `probe_smt_unproven_kind.oo`, `probe_build_is_check.oo`, etc.) fail closed if fixture files are missing
- [ ] Test runs leave zero orphaned scratch binaries or temporary files in the repository

### LLVM Backend Parity
- [ ] Intrinsics `sleep_ms`, `now_ms`, `monotonic_us`, `oo_env_get`, and `MetricsCap` lower cleanly in LLVM IR
- [ ] LLVM-backed binaries link `oodar.c` and execute without undefined symbol errors

### Bootstrap Parity & Ecosystem Verification
- [ ] Stage 1 and Stage 2 compiler binaries achieve cryptographic byte-for-byte identity ($S_1 \equiv S_2$)
- [ ] Double-run execution passes on `oodac/qa/suite.oo` ($Run_1 \equiv Run_2 = 0$)
- [ ] Universal polyrepo test suite `openOODA/qa/polyrepo_suite.oo` passes with all suites green

## Follow-up — 2026-09-13T00:01:44Z

User instruction: Please finish strong!

Ensure full zero-trust rigor through Milestone M4 (Self-Host Bootstrap & Fixed-Point Certification S1 == S2) and Milestone M5 (Universal Polyrepo Dual-Run Certification Run1 == Run2 = 0). Verify zero warnings, zero type check regressions, line limits <= 256, clean git working tree, and complete victory audit upon completion.
