<div align="center">

<pre>
   ____  ____  ___  ____    ___   ___  ____    _
  / __ \/ __ \/ _ \/ __ \  / _ \ / _ \|  _ \  / \
 / /_/ / /_/ /  __/ / / / | | | | | | | | | |/ _ \
/_____/ .___/\___/_/ /_/  | |_| | |_| | |_| / ___ \
      /_/                   \___/ \___/|____/_/   \_\
</pre>

### openOODA — Sovereign Systems Language for the AI Era

[openooda.org](https://openooda.org)

</div>

---

## This repo: oodac

Primary self-hosting compiler. Root `anchor.oo` re-exports six
surfaces: `lex`, `ast`, `check`, `types`, `emit/llvm`, and `cli`.
Product `oodac build` is LLVM IR + clang. `--backend c` / `emit-c`
/ `--gcc` are residual (exit 2). Measured auxiliary-backend status
(Audit 15, `bootstrap/corpus/backend_sweep.sh` in CI): `wasm` partial
(23/41 corpus fixtures execute byte-identical under node WASI, rest fail
closed with exit 2); `elf` minimal (2/41 int-only fixtures run natively,
rest fail closed with exit 1); `rocm` emits HIP but needs a ROCm toolchain
to compile (unproven on CI hosts); `cuda` emits `.cu` compiled by nvcc
(sm_89 default, `OODA_CUDA_ARCH` override) and links the oodar CUDA layer
(`oo_gpu_cuda_*`, proven on 2x RTX 4060 Ti). Zero silent miscompiles:
non-LLVM backends fail closed, never emit a lying binary.

## Install

```sh
curl -fsSL https://openooda.org/install.sh | bash
```

## Docs

All design, RFCs, practices, and onboarding live in [openOODA/openOODA](https://github.com/openOODA/openOODA) or at [openooda.org](https://openooda.org).

## The Polyrepo

| Repo | Purpose |
|------|---------|
| [openOODA/openOODA](https://github.com/openOODA/openOODA) | Governance, RFCs, laws |
| [openOODA/oodar](https://github.com/openOODA/oodar) | Runtime substrate |
| [openOODA/oodac](https://github.com/openOODA/oodac) | Compiler |
| [openOODA/std](https://github.com/openOODA/std) | Standard library |
| [openOODA/ooda](https://github.com/openOODA/ooda) | `ooda` workflow driver |
| [openOODA/install](https://github.com/openOODA/install) | How the toolchain lands (install.sh, apt, dnf, pacman) |
| [openOODA/opm](https://github.com/openOODA/opm) | Package manager |
| [openOODA/catalog](https://github.com/openOODA/catalog) | Public package catalog |
| [openOODA/lsp](https://github.com/openOODA/lsp) | Language server |
| [openOODA/mcp](https://github.com/openOODA/mcp) | MCP server |
| [openOODA/bb](https://github.com/openOODA/bb) | Operational Logistics: Agent-native execution flight recorder and crash autopsy engine |
| [openOODA/website](https://github.com/openOODA/website) | Website source |
| [openOODA/.github](https://github.com/openOODA/.github) | Org profile, shared community files, workflows |

## License

Apache-2.0. See [LICENSE](LICENSE) for full text.

---

<div align="center">

[![Necrometer](necrometer.svg)](https://necrometer.dev/?u=openOODA)

</div>
