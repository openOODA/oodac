# oodac: Agent Engineering Standards (v1)

This repository houses the self-hosting openOODA compiler (`.oo` -> direct LLVM IR -> native).
All work in this repository strictly defers to the organization standards in [`openOODA/AGENTS.md`](file:///home/ubermetroid/Projects/openOODA/openOODA/AGENTS.md).

---

## 1. Compiler Architecture & Invariants
- **Direct LLVM IR Emission**: Pure native compilation via LLVM IR (LLVM 18). C emission is permanently disabled.
- **Genuine AST Traversal**: Compiler passes execute real AST node visitors, typed SSA mem2reg, and typechecking. String regex heuristics and stub mock lowering are strictly prohibited.
- **Pure Native Self-Hosting**: `oodac` compiles itself without external host runtimes.

---

## 2. Invariants & Quality Standards
- **The Page Rule**: Every `.oo` page must be between 16 and 256 lines. Pure import shims skip the floor.
  - *Corpus & Fixture Exemption*: Test fixtures under `bootstrap/corpus/**` and `tests/fixtures/**` skip the 16-line floor.
- **Directory Density**: At most 8 `.oo` pages per directory.
- **4-Element Academy Header**: Mandatory on every `.oo` production file.
- **Double-Run Determinism**: `oodac tokens <file>` must produce bit-identical output across sequential runs.

---

## 3. Local Verification Commands
```bash
make check
make build
make test
```

---

## 7. Multi-Engine Audit Protocol (Pre-Release)

Advisory tiered audit run before tagging releases, budgeted by token capacity:
1. **`mcode`** (Abundant tokens): Full codebase scan for contract mismatches, packaging specs, and CI gates.  
   `mcode exec --permission full "<prompt>"`
2. **`vibe`** (Moderate tokens): Adversarial diff inspection for subtle regressions, security bypasses, and API validity.  
   `vibe -p "<prompt>" --trust --auto-approve`
3. **`grok`** (Strict quota): High-value referee and final sanity check on critical release diffs.  
   `grok -p "<prompt>" --always-approve`

**Rule:** External audits are strictly advisory; all findings must be verified against source code. External LLMs never gate CI—the §5 Verification Ladder is the sole canonical authority.
