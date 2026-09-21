#!/usr/bin/env python3
"""Challenger 1 (M2): In-Process Grammar and Expression Fuzzing Stress Suite.
Performs empirical stress testing on Grammar Mutation and Differential Fuzzers.
Adheres strictly to Academy laws: wc -l <= 256.
"""
import glob, os, random, subprocess, sys, tempfile, time

OODAC = os.path.expanduser("~/.openooda/bin/oodac")
LIBOODAR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../oodar/liboodar.a"))
SEEDS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "seeds"))
I64_MIN, I64_MAX = -9223372036854775808, 9223372036854775807

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def test_grammar_stress_2000():
    log("=== Task 1.1: Grammar Mutation 2,000 Iteration Stress Test ===")
    engine = os.path.join(os.path.dirname(__file__), "grammar_mutation_engine.py")
    with tempfile.TemporaryDirectory() as td:
        cmd = [sys.executable, engine, "--oodac", OODAC, "--seeds-dir", SEEDS_DIR,
               "--iterations", "2000", "--seed-val", "999", "--timeout-sec", "2.0",
               "--output-dir", os.path.join(td, "muts")]
        p = subprocess.run(cmd, capture_output=True, text=True)
        print(p.stdout.strip())
        if p.returncode != 0:
            log(f"FAIL: Grammar mutation 2,000 stress failed: {p.stderr}")
            return False
    log("PASS: Grammar mutation fuzzer survived 2,000 iterations without crash/hang.")
    return True

def test_adversarial_grammar_seeds():
    log("=== Task 1.2: Adversarial Grammar Inputs (Nesting, Huge IDs, Bad UTF-8) ===")
    cases = [
        ("huge_id_10k", f"pub fn id_10k() -> Int {{\n    let {'v'*10000}: Int = 1;\n    return {'v'*10000};\n}}\n"),
        ("huge_id_100k", f"pub fn id_100k() -> Int {{\n    let {'v'*100000}: Int = 1;\n    return 1;\n}}\n"),
        ("deep_nest_500", "pub fn nest() -> Int {\n    " + "{ " * 500 + "return 1; " + "} " * 500 + "\n}\n"),
        ("deep_expr_500", "pub fn de() -> Int {\n    return " + "(" * 500 + "1" + " + 1)" * 500 + ";\n}\n"),
        ("ctrl_nul", "pub fn nul() -> Int {\x00 return 1; }\n"),
        ("ctrl_esc", "pub fn esc() -> Int {\x1b return 1; }\n"),
        ("utf8_bom", "\ufeffpub fn bom() -> Int { return 1; }\n"),
        ("unclosed_str", "pub fn unclosed() -> String { return \"hello; }\n"),
    ]
    all_clean = True
    for name, code in cases:
        with tempfile.NamedTemporaryFile(suffix=".oo", mode="w", delete=False) as f:
            f.write(code)
            fpath = f.name
        try:
            p = subprocess.run([OODAC, "check", fpath], capture_output=True, text=True, timeout=2.0)
            if p.returncode not in (0, 1, 2):
                log(f"CRASH in adversarial check '{name}': rc={p.returncode}")
                all_clean = False
            elif p.returncode == 0:
                p_ll = subprocess.run([OODAC, "emit-llvm", fpath], capture_output=True, text=True, timeout=2.0)
                if p_ll.returncode not in (0, 1, 2):
                    log(f"CRASH in adversarial emit-llvm '{name}': rc={p_ll.returncode}")
                    all_clean = False
                else:
                    log(f"  [OK] {name}: check=0 emit={p_ll.returncode}")
            else:
                log(f"  [CLEAN REJECT] {name}: rc={p.returncode} ({p.stdout.strip()[:40]})")
        except subprocess.TimeoutExpired:
            log(f"HANG in adversarial input '{name}' (> 2.0s)")
            all_clean = False
        finally:
            if os.path.exists(fpath): os.unlink(fpath)
            if os.path.exists(fpath + ".art"): os.unlink(fpath + ".art")
    return all_clean

def c_div(a, b):
    if a == I64_MIN and b == -1: return I64_MIN
    s = -1 if (a < 0) ^ (b < 0) else 1
    return s * (abs(a) // abs(b))

def c_rem(a, b):
    if a == I64_MIN and b == -1: return 0
    s = -1 if a < 0 else 1
    return s * (abs(a) % abs(b))

def to_i64(v):
    return ((v + (1 << 63)) % (1 << 64)) - (1 << 63)

EDGES = [0, 1, -1, 2, -2, 63, 64, 127, 128, 2147483647, -2147483648, I64_MAX, I64_MIN]

def gen_deep_arith(rng, d, max_d, non_zero=False):
    if d >= max_d:
        v = rng.choice([x for x in EDGES if not non_zero or x != 0])
        return (str(v), v)
    op = rng.choice(['+', '-', '*', '/', '%', '&', '|', '^', '<<', '>>'])
    ls, lv = gen_deep_arith(rng, d + 1, max_d)
    rs, rv = gen_deep_arith(rng, d + 1, max_d, non_zero=(op in ('/', '%')))
    if op == '+': val = to_i64(lv + rv)
    elif op == '-': val = to_i64(lv - rv)
    elif op == '*': val = to_i64(lv * rv)
    elif op == '/': val = c_div(lv, rv)
    elif op == '%': val = c_rem(lv, rv)
    elif op == '&': val = to_i64(lv & rv)
    elif op == '|': val = to_i64(lv | rv)
    elif op == '^': val = to_i64(lv ^ rv)
    elif op == '<<': val = to_i64(lv << (rv & 63))
    elif op == '>>': val = to_i64(lv >> (rv & 63))
    if non_zero and val == 0:
        return (f"((({ls}) {op} ({rs})) + 1)", 1)
    return (f"(({ls}) {op} ({rs}))", val)

def test_differential_arith_1500():
    log("=== Task 2.1: Extended Differential Fuzzing (1,500 Deep Arith/Shift Exprs) ===")
    os.environ["OO_LIST_AMBIENT_QUOTA"] = "34359738368"
    rng = random.Random(2026)
    total_verified = 0
    batch_size = 25
    batches = int(os.environ.get("CHALLENGER_DIFF_BATCHES", "60"))
    total_expected = batches * batch_size
    with tempfile.TemporaryDirectory() as td:
        for b in range(batches):
            depth = 5 + (b % 3) # depth 5, 6, 7
            pairs = [gen_deep_arith(rng, 0, depth) for _ in range(batch_size)]
            oo_p = os.path.join(td, f"b{b}.oo")
            ll_p = os.path.join(td, f"b{b}.ll")
            bin_p = os.path.join(td, f"b{b}_bin")
            with open(oo_p, "w") as f:
                f.write("// # Arith Diff Batch\n// Logline: Deep AST arith.\n")
                f.write("// Setup: Pure.\n// Beats:\n//   1. Run.\npub fn main() -> Int {\n")
                for i, (expr_s, _) in enumerate(pairs):
                    f.write(f"    let v{i}: Int = {expr_s};\n    println(v{i}.to_string());\n")
                f.write("    return 0;\n}\n")
            p1 = subprocess.run([OODAC, "check", oo_p], capture_output=True, text=True)
            if p1.returncode != 0:
                log(f"FAIL check on batch {b}: {p1.stdout} {p1.stderr}"); return False
            p2 = subprocess.run([OODAC, "emit-llvm", oo_p], capture_output=True, text=True)
            if p2.returncode != 0:
                log(f"FAIL emit-llvm on batch {b}: {p2.stdout} {p2.stderr}"); return False
            with open(ll_p, "w") as f: f.write(p2.stdout)
            p3 = subprocess.run(["clang", "-O2", ll_p, LIBOODAR, "-lm", "-lpthread", "-o", bin_p],
                                capture_output=True, text=True)
            if p3.returncode != 0:
                log(f"FAIL clang on batch {b}: {p3.stderr}"); return False
            p4 = subprocess.run([bin_p], capture_output=True, text=True)
            act_lines = p4.stdout.strip().splitlines()
            for i, (_, exp_val) in enumerate(pairs):
                if i >= len(act_lines) or str(exp_val) != act_lines[i]:
                    log(f"MISMATCH in batch {b} expr {i}: exp={exp_val} act={act_lines[i] if i<len(act_lines) else 'EOF'}")
                    return False
            total_verified += batch_size
            if (b + 1) % 10 == 0 or b + 1 == batches:
                log(f"  Progress: {total_verified} / {total_expected} expressions verified MATCH.")
    log(f"PASS: {total_verified} deep arithmetic expressions verified bit-for-bit identical to math oracle.")
    return True

def test_surface_compound_condition_bugs():
    log("=== Task 2.2: Compound Conditional Defects & Type Checker Soundness ===")
    bug1_code = """// # Bug 1 Demonstration
// Logline: Boolean logic with compound non-Bool operand passes check but fails clang
// Setup: Pure compute
// Beats:
//   1. Logical AND with compound non-Bool
pub fn main() -> Int {
    let b: Bool = true && (10 + 20);
    if b { return 1; } else { return 0; }
}
"""
    with tempfile.NamedTemporaryFile(suffix=".oo", mode="w", delete=False) as f:
        f.write(bug1_code)
        fpath = f.name
    p1 = subprocess.run([OODAC, "check", fpath], capture_output=True, text=True)
    p2 = subprocess.run([OODAC, "emit-llvm", fpath], capture_output=True, text=True)
    ll_file = fpath + ".ll"
    with open(ll_file, "w") as f: f.write(p2.stdout)
    p3 = subprocess.run(["clang", "-O2", ll_file, LIBOODAR, "-lm", "-lpthread", "-o", fpath + "_bin"],
                        capture_output=True, text=True)
    for p in [fpath, ll_file, fpath + ".art", fpath + "_bin"]:
        if os.path.exists(p): os.unlink(p)
    log(f"Bug 1 empirical check: oodac check rc={p1.returncode}, emit-llvm rc={p2.returncode}, clang rc={p3.returncode}")
    if p1.returncode != 0:
        log("  [OK] Bug 1 regression verified: compiler rejects non-Bool compound operand (rc=1)")
        return True
    else:
        log("  [FAIL] Bug 1 regression failed: compiler accepted non-Bool compound operand")
        return False

def main():
    log("Beginning Milestone 2 Empirical Stress Challenge...")
    t0 = time.time()
    g2000_ok = test_grammar_stress_2000()
    gadv_ok = test_adversarial_grammar_seeds()
    darith_ok = test_differential_arith_1500()
    bug_regression_ok = test_surface_compound_condition_bugs()
    elapsed = time.time() - t0
    log(f"All stress phases completed in {elapsed:.2f}s.")
    log(f"Summary: Grammar 2000={g2000_ok}, Grammar Adv={gadv_ok}, Diff Arith={darith_ok}, Bug Fixed={bug_regression_ok}")
    if not (g2000_ok and gadv_ok and darith_ok and bug_regression_ok):
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
