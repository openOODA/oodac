<div align="center">

```text
   ____  ____  ___  ____    ___   ___  ____    _
  / __ \/ __ \/ _ \/ __ \  / _ \ / _ \|  _ \  / \
 / /_/ / /_/ /  __/ / / / | | | | | | | | | |/ _ \
 \____/ .___/\___/_/ /_/  | |_| | |_| | |_| / ___ \
     /_/                   \___/ \___/|____/_/   \_\
```

### [openOODA.org](https://openooda.org)

# `oodac` — Sovereign openOODA Compiler Core

</div>

The sovereign self-hosting compiler subsystem for the openOODA programming language.

## Architecture & Subsystems

`oodac` organizes 12 sovereign compiler domain subdirectories behind canonical `ANCHOR.oo` front-door entry gates:

- `lex/` — Lexical analysis, token definitions, and scanner
- `ast/` — AST parsing, module expansion, and import resolution
- `check/` — Static semantic analysis, typechecker, and typestate tracking
- `types/` — Type system primitives, unifications, and lattice definitions
- `emit/c/` — Pure ISO C emitter with ARC runtime integration
- `emit/x86/` — Direct x86-64 ELF machine code generation
- `emit/aarch64/` — Direct AArch64 ELF machine code generation & Mach-O support
- `emit/wasm/` — WebAssembly (WASM & WasmGC) binary emitter
- `emit/llvm/` — LLVM IR generator and SSA optimization passes
- `emit/gpu/` — GPU HIP/ROCm kernel lowering and AI attention emission
- `vm/` — Bytecode compiler and register VM execution engine
- `defense/` — RASP tamper defense, cryptographic integrity checks
- `cli/` — Compiler driver CLI entry points and flags

## License

openOODA is dual-licensed under Apache License, Version 2.0 or MIT license.
