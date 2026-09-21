#!/usr/bin/env python3
"""Milestone 2: Grammar Mutation Engine for openOODA Compiler Front-End.
Executes >= 1,000 iterations across 5 mutation classes with zero crashes.
Compliance: wc -l <= 256, deterministic PRNG seed, 2.0s timeout per run.
"""
import argparse, glob, os, random, subprocess, sys, time

DEFAULT_SEEDS = [
    "// # Minimal Seed\n// Logline: Minimal valid module.\n"
    "// Setup: Standalone.\n// Beats:\n//   1. Return int.\n"
    "pub fn identity(x: Int) -> Int {\n    return x + 1;\n}\n",
    "// # Contract Seed\n// Logline: Contract spec.\n// Setup: Standalone.\n"
    "// Beats:\n//   1. Precondition.\n//   2. Postcondition.\n"
    "pub fn safe_dbl(x: Int) -> Int\nrequires x >= 0\nensures result >= x\n"
    "spec \"Double\"\n{\n    return x * 2;\n}\n",
    "// # ADT Seed\n// Logline: Match ADT.\n// Setup: Standalone.\n"
    "// Beats:\n//   1. Match variant.\n"
    "pub type OptionVal = SomeVal | NoneVal;\n"
    "pub fn eval_opt(v: OptionVal) -> Int {\n"
    "    let res = match v {\n        SomeVal => 1,\n        NoneVal => 0\n"
    "    };\n    return res;\n}\n",
    "// # Struct Seed\n// Logline: Struct decl.\n// Setup: Standalone.\n"
    "// Beats:\n//   1. Field access.\n"
    "pub type Pt = struct { x: Int, y: Int };\n"
    "pub fn pt_sum(p: Pt) -> Int {\n    return p.x + p.y;\n}\n"
]

def load_seeds(seeds_dir):
    seeds = []
    if seeds_dir and os.path.isdir(seeds_dir):
        for p in sorted(glob.glob(os.path.join(seeds_dir, "*.oo"))):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    c = f.read()
                    if c.strip(): seeds.append(c)
            except Exception: pass
    return seeds if seeds else DEFAULT_SEEDS

def mutate_truncation(seed, rng):
    mode = rng.randint(0, 2)
    if mode == 0:
        return seed[:rng.randint(0, len(seed))]
    elif mode == 1:
        lines = seed.splitlines(keepends=True)
        return "".join(lines[:rng.randint(0, len(lines))])
    words = seed.split()
    return " ".join(words[:rng.randint(0, len(words))])

def mutate_token(seed, rng):
    kws = ["fn", "pub", "let", "mut", "return", "type", "requires", "ensures", "match", "if", "while"]
    mode = rng.randint(0, 3)
    if mode == 0:
        tgt = rng.choice(kws)
        rep = rng.choice(kws + ["bad_kw", "123_invalid", "struct_bad"])
        return seed.replace(tgt, rep, 1) if tgt in seed else seed + " bad_kw"
    elif mode == 1:
        bad = rng.choice(["\ufeff", "\u200b", "§", "¶", "€", "\x00", "\x7f", "\t\t\t"])
        pos = rng.randint(1, len(seed))
        return seed[:pos] + bad + seed[pos:]
    elif mode == 2:
        return seed.replace("\"", "\"\\q_bad_esc", 1) if "\"" in seed else seed + " \"\\z\""
    return seed.replace("1", "999999999999999999999999999999999999999999", 1)

def mutate_structural(seed, rng):
    mode = rng.randint(0, 4)
    if mode == 0:
        return seed + ("{" * rng.randint(1, 8))
    elif mode == 1:
        return seed + "\npub fn unclosed() { let s = \"no_close;\n"
    elif mode == 2:
        d = rng.randint(4, 30)
        return seed.replace("x + 1", "(" * d + "x + 1" + ")" * (d // 2))
    elif mode == 3:
        return seed.replace("}", ")", 1) if "}" in seed else seed + " )"
    return seed.replace("x + 1", "(x + 1)")

def mutate_scramble(seed, rng):
    mode = rng.randint(0, 2)
    if mode == 0:
        b = bytearray(seed.encode("utf-8", errors="replace"))
        for _ in range(rng.randint(1, 6)):
            if b: b[rng.randint(0, len(b) - 1)] = rng.randint(0, 255)
        return b.decode("utf-8", errors="replace")
    elif mode == 1:
        b = bytearray(seed.encode("utf-8", errors="replace"))
        pos = rng.randint(0, len(b))
        inj = bytes([rng.randint(0, 255) for _ in range(rng.randint(1, 10))])
        return (b[:pos] + inj + b[pos:]).decode("utf-8", errors="replace")
    ops = ["+ + +", "* / -", "== != >", "&& || ^^", ";;;;", "-> =>"]
    pos = rng.randint(0, len(seed))
    return seed[:pos] + " " + rng.choice(ops) + " " + seed[pos:]

def mutate_line_boundary(seed, rng):
    num_lines = rng.choice([250, 255, 256, 257, 258, 300, 500])
    padding = "// stress line padding\n" * num_lines
    return padding + seed

MUTATORS = [
    mutate_truncation, mutate_token, mutate_structural,
    mutate_scramble, mutate_line_boundary
]

def main():
    parser = argparse.ArgumentParser(description="Grammar Mutation Engine")
    parser.add_argument("--oodac", required=True, help="Path to oodac binary")
    parser.add_argument("--seeds-dir", default="", help="Path to seed directory")
    parser.add_argument("--iterations", type=int, default=1000, help="Iteration count")
    parser.add_argument("--seed-val", type=int, default=42, help="PRNG seed value")
    parser.add_argument("--timeout-sec", type=float, default=2.0, help="Timeout in seconds")
    parser.add_argument("--output-dir", required=True, help="Scratch directory")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)
    rng = random.Random(args.seed_val)
    seeds = load_seeds(args.seeds_dir)

    stats = {"valid": 0, "clean_reject": 0, "crash": 0, "hang": 0}
    t0 = time.time()
    for i in range(args.iterations):
        cls_idx = i % len(MUTATORS)
        seed = rng.choice(seeds)
        mut = MUTATORS[cls_idx](seed, rng)
        fpath = os.path.join(args.output_dir, f"mut_{i}.oo")
        with open(fpath, "w", encoding="utf-8", errors="replace") as f:
            f.write(mut)
        try:
            p = subprocess.run([args.oodac, "check", fpath], capture_output=True,
                              text=True, timeout=args.timeout_sec)
            rc = p.returncode
            if rc == 0:
                stats["valid"] += 1
                p_ll = subprocess.run([args.oodac, "emit-llvm", fpath],
                                      capture_output=True, text=True,
                                      timeout=args.timeout_sec)
                if p_ll.returncode not in (0, 1, 2):
                    stats["crash"] += 1
                    print(f"CRASH emit-llvm at {i} (class {cls_idx}): rc={p_ll.returncode}")
            elif rc in (1, 2):
                stats["clean_reject"] += 1
            else:
                stats["crash"] += 1
                print(f"CRASH check at {i} (class {cls_idx}): rc={rc} err={p.stderr}")
        except subprocess.TimeoutExpired:
            stats["hang"] += 1
            print(f"HANG at {i} (class {cls_idx})")
        finally:
            if os.path.exists(fpath): os.unlink(fpath)

    elapsed = time.time() - t0
    print(f"Ran {args.iterations} iterations in {elapsed:.2f}s:")
    print(f"  Valid (rc=0)        : {stats['valid']}")
    print(f"  Clean Rejects (rc=1,2): {stats['clean_reject']}")
    print(f"  Crashes (signals/rc>2): {stats['crash']}")
    print(f"  Hangs (> {args.timeout_sec}s)      : {stats['hang']}")

    if stats["crash"] > 0 or stats["hang"] > 0:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
