# TEST_INFRA — Opaque-Box E2E Testing Framework for openOODA/oodac

**Document Version**: 1.0.0  
**Author**: Test Writer E2E Track (`test_writer_e2e`)  
**Repository**: `openOODA/oodac`  
**Target Binary**: `~/.openooda/bin/oodac` (Release Binary per Cryptographic Binary Parity Law)  
**Constitutional Compliance**: ASD-STE100, WC-L <= 256 on All Test Files, Double-Run Determinism ($Run_1 \equiv Run_2 = 0$), Fail-Closed Anti-Vacuity Gates, Zero-Orphan Artifact Cleanup.

---

## 1. Executive Architecture & Testing Philosophy

The `oodac` compiler is the self-hosting compiler for the openOODA native language ecosystem. The end-to-end (E2E) verification suite exercises `oodac` as an opaque-box system, invoking release binaries (`~/.openooda/bin/oodac`) and standalone compiler scripts (`bootstrap/oodac_pure_build`) against concrete inputs without synthetic mocks or debug instrumentation.

### Core Testing Invariants
1. **Opaque-Box Boundary**: All tests evaluate externally observable behaviors: CLI exit codes (0 vs non-zero), standard output diagnostics, standard error messages, generated IR/C artifacts, and bit-for-bit binary convergence.
2. **Authoritative Expected Outputs**: Expected outputs are derived directly from:
   - `ORIGINAL_REQUEST.md`: R1 (Lowercase Anchor Resolution), R2 (Canonical Migration), R3 (QA Anti-Vacuity & Path Normalization), R4 (LLVM Lowering Parity & 32-Ocap Alignment), R5 (Self-Host Bootstrap & Dual-Run Certification).
   - `PROJECT.md`: 20-Feature Inventory, Milestone write boundaries, and explicit interface contracts.
   - `oodar/` runtime headers: C ABI calling conventions, capability bitmasks, and symbol prototypes.
3. **Mechanical Anti-Cheating & Empirical Falsification**:
   - *Double-Run Determinism*: Every test must execute twice ($Run_1 \equiv Run_2$). Flaky or leaking state is an automatic failure.
   - *1:1 Negative Falsification & Anti-Vacuity*: Negative tests must assert exact failure tokens. Tests that pass on missing fixtures or generic I/O errors are rejected.
   - *Cryptographic Binary Parity*: All CLI invocations target the installed release binary (`~/.openooda/bin/oodac`).
   - *Zero-Orphan Invariant*: All scratch binaries, temporary source files, and JSON autopsies are scrubbed on test exit.
4. **Governance Invariant**: Every test file, script, and test probe strictly complies with `wc -l <= 256`.

---

## 2. Test Tier Architecture

```
+-------------------------------------------------------------------------+
| Tier 4: Real-World Scenarios (Full Pure Build & Polyrepo Suite)         |
+-------------------------------------------------------------------------+
                                    ^
+-------------------------------------------------------------------------+
| Tier 3: Cross-Feature Combinations (Pairwise & Multi-Feature Pipelines)  |
+-------------------------------------------------------------------------+
                                    ^
+-------------------------------------------------------------------------+
| Tier 2: Boundary & Corner Cases (Missing Fixtures, Limits, Malformed)   |
+-------------------------------------------------------------------------+
                                    ^
+-------------------------------------------------------------------------+
| Tier 1: Primary Feature Coverage Matrix (100 Tests across 20 Features)  |
+-------------------------------------------------------------------------+
```

---

## 3. Tier 1: Feature Coverage Matrix (Features 1–20)

### Feature 1: R1 Lowercase Anchor Resolution in AST Loader (`ast/load_import_parse.oo`)
- **T1-F01-01 [Native Lowercase]**: `probe_candidate` resolves `anchor.oo` when present in target directory.
- **T1-F01-02 [Uppercase Fallback]**: When only `ANCHOR.oo` exists, `probe_candidate` smoothly falls back and resolves it.
- **T1-F01-03 [Lowercase Priority]**: When both `anchor.oo` and `ANCHOR.oo` exist, `probe_candidate` selects `anchor.oo`.
- **T1-F01-04 [Missing Anchor Fail-Closed]**: When neither anchor exists in directory, `probe_candidate` returns empty string.
- **T1-F01-05 [Direct File Resolution]**: Resolving a concrete `.oo` file directly returns the file path without appending anchor.

### Feature 2: R1 Lowercase Anchor Resolution in Typechecker (`check/check_mod.oo`)
- **T1-F02-01 [Sibling Lowercase]**: `sibling_anchor` resolves `anchor.oo` in the same directory as the source module.
- **T1-F02-02 [Sibling Uppercase Fallback]**: `sibling_anchor` falls back to `ANCHOR.oo` when `anchor.oo` is absent.
- **T1-F02-03 [Sibling Priority]**: With both present, `sibling_anchor` returns `dir + "anchor.oo"`.
- **T1-F02-04 [Nested Directory Sibling]**: Deeply nested modules (`a/b/c/mod.oo`) correctly resolve `a/b/c/anchor.oo`.
- **T1-F02-05 [Fail-Closed Read]**: Typechecker fails closed if resolved sibling anchor does not exist on disk.

### Feature 3: R1 Unused Import & CLI Anchor Handling (`check/tc_unused_import.oo`, `cli/`)
- **T1-F03-01 [Lowercase Anchor Import Not Flagged]**: Importing `anchor.oo` is exempted from unused-import warnings.
- **T1-F03-02 [Uppercase Anchor Import Not Flagged]**: Importing legacy `ANCHOR.oo` is exempted from unused-import warnings.
- **T1-F03-03 [CLI Emit-C Anchor Filter]**: `cli/cli_emit.oo` skips generating compilation units for `anchor.oo`.
- **T1-F03-04 [CLI Emit-LLVM Anchor Filter]**: `cli/cli_emit_llvm.oo` skips generating compilation units for `anchor.oo`.
- **T1-F03-05 [Unused Regular Import Flagged]**: Unused non-anchor imports trigger diagnostic warnings/errors.

### Feature 4: R1 Pure Build Script Anchor Handling (`bootstrap/oodac_pure_build`)
- **T1-F04-01 [Pure Build Lowercase Probe]**: Pure build script checks `-f "$abs/anchor.oo"` before `-f "$abs/ANCHOR.oo"`.
- **T1-F04-02 [Multi-Branch Anchor Probe]**: All 8 dependency resolution branches check lowercase `anchor.oo` first.
- **T1-F04-03 [TU Basename Filter]**: Line 282 excludes both `anchor.oo` and `ANCHOR.oo` from TU compilation units.
- **T1-F04-04 [AWK Symbol Filter]**: Line 421 filters out `(ANCHOR|anchor)_oo` symbols from deduplicated emission.
- **T1-F04-05 [Missing Entrypoint Fail-Closed]**: Pure build script terminates with exit code 1 if entrypoint is missing.

### Feature 5: R2 16 Anchor Files Lowercase Migration
- **T1-F05-01 [16 Anchors Exist]**: All 16 canonical `anchor.oo` files exist on disk in designated directories.
- **T1-F05-02 [Zero Residual Uppercase]**: Exactly 0 `ANCHOR.oo` files exist in the repository tree.
- **T1-F05-03 [Syntactic Validity]**: Every `anchor.oo` file passes `oodac check` without syntax errors.
- **T1-F05-04 [Line Limit Compliance]**: Every `anchor.oo` file satisfies `wc -l <= 256`.
- **T1-F05-05 [Non-Empty Integrity]**: No `anchor.oo` file is a 0-byte stub or truncated placeholder.

### Feature 6: R2 Documentation & Import Remediation (`docs/`, `bootstrap/seed/`)
- **T1-F06-01 [docs/anchor.oo Lowercase Imports]**: `docs/anchor.oo` imports only lowercase `.oot` files.
- **T1-F06-02 [Docs Files Exist]**: All 7 `.oot` files in `docs/` exist on disk in lowercase.
- **T1-F06-03 [Seed Docs Lowercase]**: `bootstrap/seed/readme.oot` and `bootstrap/seed/signing.oot` exist in lowercase.
- **T1-F06-04 [Docs Line Limits]**: All `.oot` files across repository satisfy `wc -l <= 256`.
- **T1-F06-05 [Missing Doc Import Fail-Closed]**: Importing a non-existent `.oot` file produces an explicit check error.

### Feature 7: R2 Brand Capitalization Preservation
- **T1-F07-01 [README Brand Token]**: `README.md` preserves exact brand capitalization `openOODA`.
- **T1-F07-02 [LICENSE Brand Token]**: `LICENSE` preserves exact brand capitalization `openOODA`.
- **T1-F07-03 [Source Code Brand Token]**: Source code comments and metadata preserve `openOODA`.
- **T1-F07-04 [No Erroneous Lowercase]**: No invalid `openooda` occurrences exist outside paths (`~/.openooda`) or URLs.
- **T1-F07-05 [Brand Linter Invariant]**: Brand consistency checker verifies 100% preservation across markdown files.

### Feature 8: R4 MetricsCap LLVM Lowering (`emit/llvm/ll_ty.oo`)
- **T1-F08-01 [MetricsCap Param Lowering]**: Function taking `m: &MetricsCap` produces valid LLVM IR with `i64`.
- **T1-F08-02 [No Unknown Type Error]**: `oodac emit-llvm` on `MetricsCap` module exits 0 with no `unknown type` error.
- **T1-F08-03 [MetricsCap Grant Lowering]**: Granting `MetricsCap` emits `@oo_cap_grant_metrics()` call.
- **T1-F08-04 [LLVM Clang Compilation]**: Generated LLVM IR compiles cleanly via `clang -c` without type errors.
- **T1-F08-05 [Invalid Capability Fail-Closed]**: Unrecognized capability name (e.g. `BogusCap`) triggers `ERR llvm unknown type`.

### Feature 9: R4 monotonic_us Lowering Parity (`emit/llvm/`)
- **T1-F09-01 [LLVM Declaration 0-Arg]**: `emit-llvm` produces `declare i64 @oo_monotonic_us()`.
- **T1-F09-02 [LLVM Call Site 0-Arg]**: `emit-llvm` produces `call i64 @oo_monotonic_us()` with 0 arguments.
- **T1-F09-03 [emit-c residual]**: `emit-c` exits residual (C backend removed).
- **T1-F09-04 [Linkage with oodar.o]**: LLVM-generated object links against `oodar.o` without calling convention mismatch.
- **T1-F09-05 [Monotonic Output Assertion]**: Executing compiled binary produces strictly positive, non-decreasing timestamps.

### Feature 10: R4 32-Ocap Symbol Linkage (`oodar.o`, `emit/llvm/ll_rt.oo`)
- **T1-F10-01 [26 Active Capabilities Present]**: All 26 `oo_cap_grant_*` symbols are present in `oodar.o`.
- **T1-F10-02 [Runtime Symbol Parity]**: All 84 runtime symbols declared in `ll_rt.oo` resolve to `oodar.o` or libc.
- **T1-F10-03 [Capability Bitmask Integrity]**: `OODAR_CAP_METRICS` (2048u) matches bit 11 in capability table.
- **T1-F10-04 [Multi-Capability Linking]**: Compiling binary requesting 6 distinct capabilities links cleanly.
- **T1-F10-05 [Missing Capability Trap]**: Ungranted capability operation fails closed with runtime trap.

### Feature 11: R3 Dynamic Path Resolution in QA Suite (`qa/suite.oo`)
- **T1-F11-01 [CWD oodac Resolution]**: Invoking `qa/suite.oo` from `oodac/` resolves all probe paths.
- **T1-F11-02 [CWD openOODA Resolution]**: Invoking `qa/suite.oo` from polyrepo root resolves probe paths via `oodac/qa/`.
- **T1-F11-03 [resolve_probe Helper]**: `resolve_probe` correctly prefixes paths when executed from parent directory.
- **T1-F11-04 [Sibling Probes Located]**: Helper probes (e.g. `probe_borrow_move.oo`) are located dynamically.
- **T1-F11-05 [Non-Existent Probe Fail-Closed]**: Invalid probe path returns `compile fail` or `cannot open file` error.

### Feature 12: R3 API Surface Probe Path Fix (`qa/probe_api_surface.oo`)
- **T1-F12-01 [Prioritizes oodac/anchor.oo]**: Checks `oodac/anchor.oo` before `anchor.oo` when invoked from polyrepo root.
- **T1-F12-02 [Polyrepo Anchor Collision Prevented]**: Does not read polyrepo root `anchor.oo` (1604 bytes).
- **T1-F12-03 [Sub-Repo Direct Invocation]**: When run inside `oodac/`, checks `anchor.oo` (1294 bytes) accurately.
- **T1-F12-04 [API Surface Token Assertions]**: Validates exported API tokens of `oodac`.
- **T1-F12-05 [Missing Anchor Fail-Closed]**: Fails closed with exit code 1 if neither anchor path exists.

### Feature 13: R3 OODA_COMPILER Forwarding (`qa/suite.oo`)
- **T1-F13-01 [OODA_COMPILER Inherited]**: Child probes inherit `OODA_COMPILER` path passed from suite runner.
- **T1-F13-02 [Stripped HOME Resiliency]**: Probes execute correctly even when `oo_child_filter_env` strips `HOME`.
- **T1-F13-03 [Explicit Compiler Override]**: Setting `OODA_COMPILER` overrides `OODA_TOOLCHAIN` and `HOME` fallbacks.
- **T1-F13-04 [Valid Compiler Check]**: Suite fails immediately if resolved compiler does not exist on disk.
- **T1-F13-05 [Non-Executable Compiler Fail-Closed]**: If compiler binary has no execute permissions, fails closed.

### Feature 14: R3 Anti-Vacuity in Negative Probes (`qa/probe_borrow_kind.oo`, etc.)
- **T1-F14-01 [Pre-Flight Fixture Existence]**: `probe_borrow_kind.oo` asserts `path_exists` for test victims before executing.
- **T1-F14-02 [Missing Fixture Fail-Closed]**: Deleting a victim fixture causes probe to exit 1 (`fixtures missing`).
- **T1-F14-03 [Exact Diagnostic Assertion]**: Probes assert semantic error strings (`"use after move"`, `"mut alias"`).
- **T1-F14-04 [SMT Unsat / Unproven Tokens]**: `probe_smt_false_kind` and `probe_smt_unproven_kind` check `"unsat"`/`"unproven"`.
- **T1-F14-05 [Lattice Audit Fixture Check]**: `probe_lattice_audit` asserts fixture write success and fails if I/O fails.

### Feature 15: R3 Zero-Orphan Artifact Cleanup
- **T1-F15-01 [Probe Binary Scrubbing]**: All probes delete `.tmp.bin` artifacts immediately upon completion.
- **T1-F15-02 [Autopsy JSON Scrubbing]**: `probe_blackbox_autopsy` scrubs `.blackbox/autopsy.json` and temporary ELFs.
- **T1-F15-03 [Lattice Temp Scrubbing]**: `probe_lattice_audit` deletes `/tmp/lattice_secret.oo` and `/tmp/lattice_hold.bin`.
- **T1-F15-04 [Working Tree Cleanliness]**: `git status -s` produces zero untracked scratch artifacts after test runs.
- **T1-F15-05 [Failure Path Traps]**: Cleanup hooks execute even when individual test assertions fail.

### Feature 16: R5 Deterministic Stage 1 & 2 Compilation (`bootstrap/oodac_pure_build`)
- **T1-F16-01 [Stage 1 Compilation]**: Pure build produces valid Stage 1 compiler binary.
- **T1-F16-02 [Stage 2 Compilation]**: Stage 1 compiler successfully self-hosts and produces Stage 2 compiler binary.
- **T1-F16-03 [Deterministic Flags Applied]**: `-g0`, `-fno-ident`, `-frandom-seed=0`, `-Wl,--build-id=none` enforced.
- **T1-F16-04 [All 243 Modules Compiled]**: Both stages compile the exact set of 243 self-hosted compiler modules.
- **T1-F16-05 [Execution Smoke Test]**: Both S1 and S2 execute `--help` and `check main.oo` identically.

### Feature 17: R5 Cryptographic Fixed-Point Verification ($S_1 \equiv S_2$)
- **T1-F17-01 [SHA-256 Binary Equality]**: `sha256(S1) == sha256(S2)` bit-for-bit identity verified.
- **T1-F17-02 [Byte-for-Byte cmp Verification]**: `cmp S1 S2` returns 0 with zero byte discrepancies.
- **T1-F17-03 [Synthetic Difference Fail-Closed]**: Injected bitflip between S1 and S2 causes pure build to exit 1.
- **T1-F17-04 [Warm Rebuild Stability]**: Re-running pure build on cached emit preserves cryptographic identity.
- **T1-F17-05 [Output Artifact Verification]**: Final verified binary is installed to destination path.

### Feature 18: R5 Strict Line Limit Enforcement (`wc -l <= 256`)
- **T1-F18-01 [Compiler Source Files <= 256]**: All `.oo` files in `ast/`, `check/`, `cli/`, `emit/`, `lex/`, `types/` <= 256 lines.
- **T1-F18-02 [Documentation Files <= 256]**: All `.oot` files in `docs/` <= 256 lines.
- **T1-F18-03 [QA Probes <= 256]**: All `.oo` probes in `qa/` <= 256 lines.
- **T1-F18-04 [E2E Test Suite Files <= 256]**: All newly created test files and runner scripts <= 256 lines.
- **T1-F18-05 [Adversarial Boundary Validation]**: `boundary_256_lines.oo` passes; `boundary_257_lines.oo` triggers violation.

### Feature 19: R5 Dual-Run oodac QA Suite Verification ($Run_1 \equiv Run_2 = 0$)
- **T1-F19-01 [Suite Run 1 Passes]**: First run of all 13 probes in `qa/suite.oo` exits 0.
- **T1-F19-02 [Suite Run 2 Passes]**: Second run of all 13 probes in `qa/suite.oo` exits 0.
- **T1-F19-03 [Identical Output Log]**: Output log of Run 1 matches Run 2 identically.
- **T1-F19-04 [13 Probes Executed]**: All 13 canonical probes execute in order.
- **T1-F19-05 [Any Probe Failure Halts]**: Injecting a failure in any probe halts suite immediately and returns non-zero.

### Feature 20: R5 Polyrepo Suite Dual-Run Verification ($Run_1 \equiv Run_2 = 0$)
- **T1-F20-01 [Polyrepo Run 1 Passes]**: All 6 packages (`std`, `ooda`, `mcp`, `lsp`, `opm`, `oodac`) pass Run 1.
- **T1-F20-02 [Polyrepo Run 2 Passes]**: All 6 packages pass Run 2 with zero regressions.
- **T1-F20-03 [Scorecard 10/10]**: Polyrepo target criteria evaluation achieves 10/10 across both runs.
- **T1-F20-04 [Specific Excess Power Rating]**: Performance metric rating matches expected baseline.
- **T1-F20-05 [Package Isolation]**: Sub-suite failure in any package immediately stops polyrepo suite.

---

## 4. Tier 2: Boundary & Corner Cases

- **T2-B01 [Missing Fixture Fail-Closed]**: Negative probe with deleted victim file terminates with exit code 1 and specific diagnostic.
- **T2-B02 [Uppercase Fallback Integrity]**: Directory containing ONLY `ANCHOR.oo` compiles without missing import error.
- **T2-B03 [Empty Input File]**: 0-byte `.oo` file passed to `check` fails closed with header/syntax error.
- **T2-B04 [Exact Boundary 256 Lines]**: File with exactly 256 lines passes line limit governance check.
- **T2-B05 [Boundary Breach 257 Lines]**: File with 257 lines is flagged as a governance boundary violation.
- **T2-B06 [Unused Token Threshold 401]**: `boundary_401_tokens_unused.oo` triggers unused token threshold error.
- **T2-B07 [Malformed Header Blank]**: `invalid_header_blank.oo` fails closed with invalid header error.
- **T2-B08 [Malformed Header Inline]**: `invalid_header_inline.oo` fails closed with invalid header error.
- **T2-B09 [Invalid Struct Trailing Comma]**: `invalid_struct_comma.oo` fails closed with syntax parse error.
- **T2-B10 [Invalid Syntax Expression]**: `invalid_syntax.oo` fails closed with parse error.
- **T2-B11 [Invalid Type Specification]**: `invalid_type.oo` fails closed with unknown type error.
- **T2-B12 [Ambient Capability Leak]**: `invalid_cap_ambient.oo` fails closed with capability violation error.
- **T2-B13 [Secret Taint Leak]**: `secret_taint_leak.oo` fails closed with taint analysis violation.
- **T2-B14 [Secret Taint Valid]**: `secret_taint_valid.oo` passes taint analysis with proper attenuation.
- **T2-B15 [Landlock Path Escape]**: Access outside `OODA_FS_READDIR` triggers Landlock sandbox denial.

---

## 5. Tier 3: Cross-Feature Combinations

- **T3-X01 [MetricsCap + Lowercase Anchor Import]**: Module importing `anchor.oo` and using `MetricsCap` compiles under LLVM backend.
- **T3-X02 [Dual CWD Execution Parity]**: Running compiler checks from `oodac/` vs `openOODA/` yields byte-identical results.
- **T3-X03 [LLVM Lowering + 32-Ocap Linkage]**: Module using `MetricsCap`, `sleep_ms`, `now_ms`, `monotonic_us`, and `oo_env_get` compiles and links against `oodar.o`.
- **T3-X04 [Dynamic Path Resolution + Anti-Vacuity]**: Negative probes correctly locate fixtures when invoked from polyrepo root and fail closed if missing.
- **T3-X05 [Pure Build + Lowercase Anchors]**: `bootstrap/oodac_pure_build` processes 243 modules where all anchors are lowercase `anchor.oo`.
- **T3-X06 [Pure Build + LLVM Lowering]**: Pure build Stage 1 and Stage 2 emit LLVM IR utilizing all lowered intrinsics.
- **T3-X07 [Zero-Orphan Cleanup + Dual-Run]**: Running test suite twice in succession produces 0 residual files after each run.
- **T3-X08 [OODA_COMPILER Forwarding + Polyrepo Suite]**: Polyrepo suite forwards compiler path to all 6 package suites without environment bleed.
- **T3-X09 [Line Limit Verification Across All 16 Migrated Anchors]**: Automated scan proves every migrated `anchor.oo` complies with `wc -l <= 256`.
- **T3-X10 [S1==S2 Convergence + Suite Verification]**: Bootstrapped S2 compiler successfully runs `qa/suite.oo` with zero defects.

---

## 6. Tier 4: Real-World Application Scenarios
- **T4-RW01 [Actor Event Bus Engine]**: `app_actor_event_bus.oo` compiles, links, runs deterministically.
- **T4-RW02 [Compiler Plugin Driver]**: `app_compiler_plugin.oo` executes plugin lifecycle.
- **T4-RW03 [Crypto Pipeline Engine]**: `app_crypto_pipeline.oo` executes cryptographic pipeline.
- **T4-RW04 [Matrix Sensor Fusion Engine]**: `app_matrix_sensor_fusion.oo` executes sensor fusion.
- **T4-RW05 [Secure Vault Controller]**: `app_secure_vault.oo` verifies capability boundaries.
- **T4-RW06 [Full Pure Build Self-Hosting]**: `oodac_pure_build` certifies $S_1 \equiv S_2$.
- **T4-RW07 [Full Polyrepo Ecosystem Suite]**: Complete execution of `polyrepo_suite.oo`.
- **T4-RW08 [Clean Repository Tree Audit]**: `git status -s` audit verifying zero untracked artifacts.

## 7. Execution Harness & Governance Architecture
Modular test files in `tests/e2e/` (strictly `<= 256 lines`):
- `run_all.sh`: Master E2E runner (double-run determinism, scorecard, line limits)
- `test_tier1_r1_anchor.sh`: Features 1-4 (Anchor resolution, pure_build)
- `test_tier1_r2_migrate.sh`: Features 5-7 (16 anchors, docs, brand tokens)
- `test_tier1_r4_llvm.sh`: Features 8-10 (MetricsCap, monotonic_us, 32-Ocap)
- `test_tier1_r3_qa.sh`: Features 11-15 (Dynamic paths, anti-vacuity, cleanup)
- `test_tier1_r5_boot.sh`: Features 16-20 (Pure build, fixed-point, dual-run)
- `test_tier2_boundary.sh`: Tier 2 boundary, corner cases, and malformed inputs
- `test_tier3_cross.sh`: Tier 3 cross-feature combinations and pairwise pipelines
- `test_tier4_realworld.sh`: Tier 4 real-world scenarios and ecosystem suites

### Execution Invariants
- Tests execute with `set -euo pipefail`.
- Scratch artifacts written to `/tmp/oodac_e2e_$$/` and scrubbed via `trap ... EXIT INT TERM`.
- Every test module verifies both Run 1 and Run 2 ($Run_1 \equiv Run_2 = 0$).
