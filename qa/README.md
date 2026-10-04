# QA Probes and Harness Layout

This directory contains test probes, fixtures, and verification harnesses for `oodac`.

## Directory Layout

- `qa/*.oo`: Standalone verification probes and regression tests executed during compiler validation.
- `qa/fixtures/`: Shared test fixtures and helper `.oo` modules used by multiple probes.
- `qa/nested/`: Nested-import and module-graph edge case tests validating topological resolution and diamond dependency handling.
