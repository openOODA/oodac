# QA Probes and Harness Layout

This directory contains test probes, fixtures, and verification harnesses for `oodac`.

## Directory Layout

- `qa/*.oo`: Standalone verification probes and regression tests executed during compiler validation.
- `qa/fixtures/`: Shared test fixtures and helper `.oo` modules used by multiple probes.
- `qa/cabi_challenge/`: C-ABI conformance challenge suite containing mixed-provenance C (`harness_main.c`) and `.oo` contracts to verify standard calling conventions, struct passing, and primitive layout across language boundaries.
- `qa/nested/`: Nested-import and module-graph edge case tests validating topological resolution and diamond dependency handling.
- `qa/devin_repros/`: Isolated reproducers for SWE-2 audit defects (`d01_deref_store.oo` through `d17_nsw_wrap.oo`), each verifying a specific compiler frontend/backend bug fix.
