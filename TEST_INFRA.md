# TEST_INFRA — Sovereign oodac Compiler Core E2E Test Infrastructure
File: oodac/TEST_INFRA.md

## 1. Test Philosophy & Core Invariants

The `oodac` sovereign compiler test infrastructure enforces zero-trust verification grounded in openOODA's 10 Strategic Governance Pillars (`NORTHSTAR.oot` and `RULES.oot`). Every test in this suite adheres to the following immutable principles:

1. **Opaque-Box Requirement-Driven Verification**: Tests validate compiler behavior through external observable interfaces (exit codes, standard output/error, AST representations, emitted artifacts, diagnostics) rather than internal private state.
2. **Negative-Trust Adversarial Falsification (Pillar 3 / RULES §1.10)**: Assume unproven stubs and claims are defective. Every feature requires negative test cases that actively probe boundary limits, corrupted inputs, forged capability tokens, and syntax deviations.
3. **Double-Run Invariant (Pillar 3 / RULES §1.4)**: Every test execution must satisfy $\text{Run}_1(\text{Test}) \equiv \text{Run}_2(\text{Test})$ in isolated, clean processes. Builds and test results must be bit-identical and state-invariant.
4. **Anti-Cheat Honesty & Real Pipelines (RULES §1.1)**: Tests must exercise genuine compiler lowering pipelines, AST traversal, and typechecking. Facade tests that unconditionally succeed without evaluating actual inputs are prohibited.
5. **Zero Ambient Authority (Pillar 5)**: Tests explicitly assert that all privileged operations (filesystem, process execution, environment, sys calls) are mediated by the 14 unforgeable capability tokens (`&FsReadCap`, `&FsWriteCap`, `&ProcessCap`, `&SysCap`, etc.).

---

## 2. The 4-Tier Test Architecture

The E2E test suite is organized into a four-tier verification pyramid:

```
                  ┌──────────────────────────────┐
                  │ Tier 4: Real-World Scenarios │
                  │  (>=5 End-to-End Apps)       │
                  ├──────────────────────────────┤
                  │ Tier 3: Cross-Feature Combos │
                  │  (Pairwise Interactions)     │
                  ├──────────────────────────────┤
                  │ Tier 2: Boundary & Corners   │
                  │  (>=5 Per Feature = 85 Tests)│
                  ├──────────────────────────────┤
                  │ Tier 1: Feature Coverage     │
                  │  (>=5 Per Feature = 85 Tests)│
                  └──────────────────────────────┘
```

### Tier 1: Feature Coverage (85 Tests)
- **Scope**: Direct, requirement-driven verification of each of the 17 features defined in `PROJECT.md`.
- **Threshold**: $\ge 5$ distinct test cases per feature ($17 \times 5 = 85$ tests minimum).
- **Focus**: Functional correctness, interface compliance, exported symbol resolution, structural rules, and feature-specific acceptance criteria.

### Tier 2: Boundary & Corner Cases (85 Tests)
- **Scope**: Boundary Value Analysis (BVA) and extreme corner cases for each of the 17 features.
- **Threshold**: $\ge 5$ boundary test cases per feature ($17 \times 5 = 85$ tests minimum).
- **Focus**: Minimum/maximum buffer sizes, line limit boundaries (256 vs 257 lines), empty input streams, deeply nested AST nodes, Unicode paths, corrupted tokens, and zero-byte payloads.

### Tier 3: Cross-Feature Combinations (10 Tests)
- **Scope**: Pairwise combinatorial testing across subsystem seams and architectural boundaries.
- **Threshold**: $\ge 10$ orthogonal pairwise combinations covering major multi-subsystem flows.
- **Focus**: Interactions between entry gates and typechecking, headers and line limits, dead subsystems and shims, cascades and hardened process execution, capability tokens and secret taint, etc.

### Tier 4: Real-World Application Scenarios (5 Applications)
- **Scope**: Complete, realistic, self-contained openOODA programs demonstrating end-to-end sovereign execution.
- **Threshold**: $\ge 5$ production-grade `.oo` applications.
- **Applications**:
  1. `app_secure_vault.oo`: Zero-trust secret vault with capabilities, typestates, and refinement types.
  2. `app_crypto_pipeline.oo`: Pure cryptographic Merkle hashing and signature pipeline with deterministic ARC.
  3. `app_matrix_sensor_fusion.oo`: Boyd's E-M sensor fusion engine with linear arena bounds and SMT contracts.
  4. `app_actor_event_bus.oo`: Actor-based message router with ADT sum types and exhaustive pattern matching.
  5. `app_compiler_plugin.oo`: Standalone mini-compiler pass performing tokenization and dead-code analysis.

---

## 3. Testing Methodologies

### 3.1 Category-Partition Method
For every compiler feature, input spaces are systematically partitioned into disjoint equivalence classes:
- Valid / Canonical inputs (expected to pass cleanly).
- Boundary inputs (on the exact threshold of validity).
- Malformed / Out-of-bounds inputs (expected to fail closed with precise diagnostics).
- Adversarial inputs (containing escape sequences, metacharacters, or forged tokens).

### 3.2 Boundary Value Analysis (BVA)
BVA is systematically applied to numeric, structural, and semantic parameters:
- File line limits: 1 line (minimal), 255 lines (nominal max), 256 lines (exact ceiling), 257 lines (rejected).
- Token count thresholds in linters: 399 tokens, 400 tokens, 401 tokens (verifying zero-bypass rule).
- Struct fields: 0 fields (empty struct), 1 field, 64 fields, trailing comma presence.
- Memory arena bounds: 0-byte allocation, page-aligned allocation, arena overflow.

### 3.3 Pairwise Combinatorial Testing
Architectural seams are audited by pairing distinct subsystem requirements to prevent regression across module boundaries:
- Entry Gate Reparation (F1) $\times$ Domain Typecheck Assurance (F3)
- Academy Headers (F2) $\times$ Line Limits / Boyd's E-M (F14)
- Dead Subsystems (F4) $\times$ Transitional Shims (F5)
- Cascade Removal (F6) $\times$ Shell Execution Hardening (F12)
- Misleading File Normalization (F7) $\times$ Logic Deduplication (F8)
- Linter Bypass Removal (F9) $\times$ Dead Import Purge (F10)
- Filesystem Capability (F11) $\times$ Process Capability (F12)
- AST Secret Taint (F13) $\times$ Static Capability Enforcement (F11)
- Version Contract (F17) $\times$ API Surface Integrity (F3)
- E-M Optimization (F14) $\times$ Double-Run Determinism (F15)

### 3.4 Real-World Workload Simulation
Real-world applications evaluate the integrated compiler toolchain on complex software constructs without relying on mock stubs or canned fixtures.

---

## 4. Feature Coverage Matrix (17 Features)

| # | Feature Name | Tier 1 (Coverage) | Tier 2 (Boundary) | Tier 3 (Pairwise) | Milestone |
|---|---|---|---|---|---|
| 1 | Entry Gate Reparation | `t1_feat01_*` (5) | `t2_feat01_*` (5) | `comb01` | M1 |
| 2 | Academy Header Normalization | `t1_feat02_*` (5) | `t2_feat02_*` (5) | `comb02` | M1 |
| 3 | Domain Typecheck Assurance | `t1_feat03_*` (5) | `t2_feat03_*` (5) | `comb01`, `comb09` | M1 |
| 4 | Dead Subsystem Excising | `t1_feat04_*` (5) | `t2_feat04_*` (5) | `comb03` | M2 |
| 5 | Transitional Shim Elimination | `t1_feat05_*` (5) | `t2_feat05_*` (5) | `comb03` | M2 |
| 6 | Side-Channel & Cascade Removal | `t1_feat06_*` (5) | `t2_feat06_*` (5) | `comb04` | M2 |
| 7 | Misleading File Normalization | `t1_feat07_*` (5) | `t2_feat07_*` (5) | `comb05` | M2 |
| 8 | Logic Deduplication | `t1_feat08_*` (5) | `t2_feat08_*` (5) | `comb05` | M3 |
| 9 | Linter Bypass Elimination | `t1_feat09_*` (5) | `t2_feat09_*` (5) | `comb06` | M3 |
| 10 | Dead Import & Function Purge | `t1_feat10_*` (5) | `t2_feat10_*` (5) | `comb06` | M3 |
| 11 | Filesystem Ambient Auth Removal | `t1_feat11_*` (5) | `t2_feat11_*` (5) | `comb07`, `comb08` | M4 |
| 12 | Shell Execution Hardening | `t1_feat12_*` (5) | `t2_feat12_*` (5) | `comb04`, `comb07` | M4 |
| 13 | AST Dataflow Secret Taint | `t1_feat13_*` (5) | `t2_feat13_*` (5) | `comb08` | M4 |
| 14 | Boyd's E-M Metric Pruning | `t1_feat14_*` (5) | `t2_feat14_*` (5) | `comb02`, `comb10` | M4 |
| 15 | E2E Testing Suite (Tiers 1-4) | `t1_feat15_*` (5) | `t2_feat15_*` (5) | `comb10` | M5 |
| 16 | Adversarial Coverage Hardening | `t1_feat16_*` (5) | `t2_feat16_*` (5) | All | M5 |
| 17 | Version Contract & Release Parity | `t1_feat17_*` (5) | `t2_feat17_*` (5) | `comb09` | M6 |

---

## 5. Test Infrastructure Directory Layout

```
oodac/tests/
├── run_e2e_tests.sh              # Primary test suite runner
├── test_runner_core.sh           # Reusable assertion & harness engine
├── fixtures/                     # Test fixtures and synthetic source files
│   ├── valid_program.oo
│   ├── syntax_error.oo
│   ├── type_error.oo
│   ├── cap_violation.oo
│   ├── secret_leak.oo
│   └── ...
├── tier1_features/               # Tier 1: 17 feature directories (>=5 tests each)
│   ├── feat01_entry_gates/
│   ├── feat02_academy_headers/
│   ├── ...
│   └── feat17_version_contract/
├── tier2_boundary/               # Tier 2: 17 boundary directories (>=5 tests each)
│   ├── feat01_boundary/
│   ├── feat02_boundary/
│   ├── ...
│   └── feat17_boundary/
├── tier3_combinations/           # Tier 3: 10 pairwise interaction test cases
│   ├── comb01_entry_and_typecheck/
│   ├── ...
│   └── comb10_boyd_em_and_determinism/
└── tier4_realworld/              # Tier 4: 5 production application programs
    ├── app_secure_vault.oo
    ├── app_crypto_pipeline.oo
    ├── app_matrix_sensor_fusion.oo
    ├── app_actor_event_bus.oo
    └── app_compiler_plugin.oo
```

---

## 6. Test Runner Specifications (`tests/run_e2e_tests.sh`)

### 6.1 Invocation & Environment
The test runner is executed directly via `bash`:
```bash
./tests/run_e2e_tests.sh [options]
```

Key environment variables:
- `OODA_BIN`: Path to `oodac` compiler CLI driver (defaults to `/home/jeryd/Projects/openOODA/oodac/bin/oodac`).
- `OODAC_ROOT`: Path to `oodac` source root (defaults to repository root).
- `DOUBLE_RUN`: When set to `1`, executes the double-run determinism verification protocol.

### 6.2 Exit Code Semantics
- `0`: All executed test cases passed with zero errors.
- `1`: One or more test assertions failed.
- `2`: Harness configuration error or missing prerequisites.

### 6.3 Diagnostic Output
The runner emits concise, machine-parseable progress updates and a structured summary:
- `[PASS]` / `[FAIL]` indicators for each test case.
- Group summaries by tier and feature ID.
- Aggregate metrics: Total, Passed, Failed, Duration.
- Formatted strictly to $<80$ characters per terminal line.
