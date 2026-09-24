# vs-rustc stretch results (measurement only, NOT gated)

Directory: `oodac/bootstrap/corpus/vs-rustc-stretch/`
Harness: `oodac/tests/e2e/test_vs_rustc_stretch.sh` (same method as the
frozen six: stdout bit-parity, then interleaved median-of-5 wall clock
per side, per-program ratio = oodac_med / rustc_med).
The frozen six (`bootstrap/corpus/vs-rustc/`, `test_vs_rustc.sh`) are untouched.

## Host

- rustc 1.96.1 (31fca3adb 2026-06-26), flags `-C opt-level=3 -C lto=thin -C panic=abort`
- clang 22.1.8 (Fedora 22.1.8-4.fc44), oodac `build` (`clang -O2`)
- oodac binary `$HOME/.openooda/bin/oodac`, `OODA_OPT_LEVEL=3`
- Date: 2026-09-24. Two consecutive runs; both 5/5 stdout parity.

## Numbers (run 1 / run 2)

| Program | Shape | oodac_med (s) | rustc_med (s) | Ratio r1 | Ratio r2 |
|---|---|---|---|---|---|
| strbuild | string-heavy: 6000-record CSV concat + predicates | 0.1921 | 0.00125 | 154.26 | 145.40 |
| listxform | list-heavy: 200k push, in-place double, sum, slice | 0.0147 | 0.00228 | 6.47 | 6.07 |
| nested | nested structs: Company/Dept/Employee + 100k hires | 0.0527 | 0.00454 | 11.60 | 11.08 |
| errpath | error paths: 300k Result validations + messages | 0.00655 | 0.00293 | 2.23 | 2.08 |
| logscan | mixed: 60k List[String] build + substring scan | 0.0450 | 0.00766 | 5.87 | 7.45 |

Stretch geo-mean (oodac/rustc): **10.8707 (run 1), 10.8642 (run 2)**.
For context the frozen six gate on this host class was 0.9034 (R6, v0.5.0).

## Honest reading

- Parity holds 5/5: every stretch program prints byte-identical stdout on both sides.
- On real-world shapes oodac is ~2x–150x slower than rustc -O3, not at parity.
  The gap is a normalizer away, not a codegen cliff: repeated `String +`
  concat reallocates per append (strbuild dominates the mean), and list /
  struct / Result paths carry ARC/runtime overhead rustc optimizes out.
- errpath (2.1x–2.2x) is closest: integer Result pipelines lower well.
- These numbers do NOT move the 10/10 bar (`docs/llvm-rustc-bar.oot`
  forbids a 7th program; this corpus lives in a separate directory and the
  stretch script enforces no threshold).

## Reproduce

```sh
bash oodac/tests/e2e/test_vs_rustc_stretch.sh
```
