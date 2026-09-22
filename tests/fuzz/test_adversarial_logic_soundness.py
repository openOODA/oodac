#!/usr/bin/env python3
"""Adversarial challenger: Logical Operator Type Soundness.
Exhaustively stresses Finding 1 remediation across negative (must fail rc=1)
and positive (must pass check, build, run) compound logical expressions.
Compliance: wc -l <= 256.
"""
import os, subprocess, sys, tempfile

OODAC = os.path.expanduser("~/.openooda/bin/oodac")
LIBOODAR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../oodar/liboodar.a")
)

def run_cmd(cmd, timeout=5.0):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)

def test_negative_cases():
    print(">>> [Task 1.1] Testing Negative Compound Logic (MUST FAIL closed rc=1)...")
    cases = [
        # Requested in prompt
        ("true && (10 + 20)", "pub fn main() -> Int {\n    let b: Bool = true && (10 + 20);\n    return 0;\n}\n"),
        ("(x + y) || false", "pub fn main() -> Int {\n    let x: Int = 1;\n    let y: Int = 2;\n    let b: Bool = (x + y) || false;\n    return 0;\n}\n"),
        ("true && (false || (1 + 2))", "pub fn main() -> Int {\n    let b: Bool = true && (false || (1 + 2));\n    return 0;\n}\n"),
        # Additional edge cases
        ("(10 + 20) && true", "pub fn main() -> Int {\n    let b: Bool = (10 + 20) && true;\n    return 0;\n}\n"),
        ("false || (x + y)", "pub fn main() -> Int {\n    let x: Int = 1;\n    let y: Int = 2;\n    let b: Bool = false || (x + y);\n    return 0;\n}\n"),
        ("(1 + 2) || (3 + 4)", "pub fn main() -> Int {\n    let b: Bool = (1 + 2) || (3 + 4);\n    return 0;\n}\n"),
        ("true && (false && (true || (10 * 20)))", "pub fn main() -> Int {\n    let b: Bool = true && (false && (true || (10 * 20)));\n    return 0;\n}\n"),
        ("(a == b) && (1 + 2)", "pub fn main() -> Int {\n    let a: Int = 1;\n    let b: Int = 1;\n    let res: Bool = (a == b) && (1 + 2);\n    return 0;\n}\n"),
        ("(1 + 2) && (a == b)", "pub fn main() -> Int {\n    let a: Int = 1;\n    let b: Int = 1;\n    let res: Bool = (1 + 2) && (a == b);\n    return 0;\n}\n"),
        ("(x & y) && (a == b)", "pub fn main() -> Int {\n    let x: Int = 1;\n    let y: Int = 2;\n    let a: Int = 3;\n    let b: Int = 3;\n    let res: Bool = (x & y) && (a == b);\n    return 0;\n}\n"),
        ("(a == b) && (x | y)", "pub fn main() -> Int {\n    let x: Int = 1;\n    let y: Int = 2;\n    let a: Int = 3;\n    let b: Int = 3;\n    let res: Bool = (a == b) && (x | y);\n    return 0;\n}\n"),
        ("(x ^ y) || (a != b)", "pub fn main() -> Int {\n    let x: Int = 1;\n    let y: Int = 2;\n    let a: Int = 3;\n    let b: Int = 3;\n    let res: Bool = (x ^ y) || (a != b);\n    return 0;\n}\n"),
        ("true && 42", "pub fn main() -> Int {\n    let b: Bool = true && 42;\n    return 0;\n}\n"),
        ("42 || false", "pub fn main() -> Int {\n    let b: Bool = 42 || false;\n    return 0;\n}\n"),
        ("true && \"hello\"", "pub fn main() -> Int {\n    let b: Bool = true && \"hello\";\n    return 0;\n}\n"),
        ("\"str\" || false", "pub fn main() -> Int {\n    let b: Bool = \"str\" || false;\n    return 0;\n}\n"),
        ("((((10 + 20)))) && true", "pub fn main() -> Int {\n    let b: Bool = ((((10 + 20)))) && true;\n    return 0;\n}\n"),
        ("fn_returning_int", "fn get_int() -> Int {\n    return 42;\n}\npub fn main() -> Int {\n    let b: Bool = true && get_int();\n    return 0;\n}\n"),
    ]

    all_pass = True
    for name, code in cases:
        with tempfile.NamedTemporaryFile(suffix=".oo", mode="w", delete=False) as f:
            f.write(code)
            src_path = f.name
        try:
            p = run_cmd([OODAC, "check", src_path])
            if p.returncode != 1:
                print(f"  FAIL: '{name}' expected rc=1, got rc={p.returncode}\nStdout: {p.stdout}\nStderr: {p.stderr}")
                all_pass = False
            else:
                # Confirm error message indicates logical operator type error
                has_msg = "logical operator requires Bool operands" in p.stdout or "logical operator requires Bool operands" in p.stderr or "Type error" in p.stdout
                print(f"  [OK] '{name}': cleanly rejected with rc=1 (diagnostic confirmed: {has_msg})")
        finally:
            for ext in ["", ".art", ".ll"]:
                if os.path.exists(src_path + ext): os.unlink(src_path + ext)
    return all_pass

def test_positive_complex_cases():
    print(">>> [Task 1.2] Testing Positive Complex Logic (Check, Build, Run)...")
    # Prompt case: (a > 0 && b < 10) || (c == 5 && d != 2)
    # We test with multiple (a, b, c, d) inputs and verify expected boolean evaluation
    code_tmpl = """// # Complex Valid Logic Test
// Logline: Multi-branch condition evaluation
// Setup: Pure compute
// Beats:
//   1. Evaluate expression and return 1 if true, 0 if false
pub fn eval_cond(a: Int, b: Int, c: Int, d: Int) -> Int {
    if (a > 0 && b < 10) || (c == 5 && d != 2) {
        return 1;
    } else {
        return 0;
    }
}
pub fn main() -> Int {
    let r1: Int = eval_cond(1, 5, 0, 0);   // true || false -> 1
    let r2: Int = eval_cond(-1, 5, 5, 3);  // false || true -> 1
    let r3: Int = eval_cond(-1, 5, 5, 2);  // false || false (d==2) -> 0
    let r4: Int = eval_cond(1, 20, 0, 0);  // false || false -> 0
    let r5: Int = eval_cond(5, 5, 5, 5);   // true || true -> 1
    println(r1.to_string());
    println(r2.to_string());
    println(r3.to_string());
    println(r4.to_string());
    println(r5.to_string());
    return 0;
}
"""
    with tempfile.NamedTemporaryFile(suffix=".oo", mode="w", delete=False) as f:
        f.write(code_tmpl)
        src_path = f.name
    try:
        p_chk = run_cmd([OODAC, "check", src_path])
        if p_chk.returncode != 0:
            print(f"  FAIL check on complex valid logic: rc={p_chk.returncode}\n{p_chk.stderr}")
            return False
        p_emit = run_cmd([OODAC, "emit-llvm", src_path])
        if p_emit.returncode != 0:
            print(f"  FAIL emit-llvm: rc={p_emit.returncode}\n{p_emit.stderr}")
            return False
        ll_path = src_path + ".ll"
        with open(ll_path, "w") as f:
            f.write(p_emit.stdout)
        bin_path = src_path + "_bin"
        p_clang = run_cmd(["clang", "-O2", ll_path, LIBOODAR, "-lm", "-lpthread", "-o", bin_path])
        if p_clang.returncode != 0:
            print(f"  FAIL clang build: rc={p_clang.returncode}\n{p_clang.stderr}")
            return False
        p_run = run_cmd([bin_path])
        if p_run.returncode != 0:
            print(f"  FAIL execution: rc={p_run.returncode}")
            return False
        out_lines = p_run.stdout.strip().splitlines()
        expected = ["1", "1", "0", "0", "1"]
        if out_lines != expected:
            print(f"  FAIL output mismatch: expected {expected}, got {out_lines}")
            return False
        print(f"  [OK] Complex expression '(a > 0 && b < 10) || (c == 5 && d != 2)' passed all 5 truth-table points.")
    finally:
        for p in [src_path, src_path + ".art", src_path + ".ll", src_path + "_bin"]:
            if os.path.exists(p): os.unlink(p)

    # Additional complex valid cases: deep nesting, parenthesized subconditions, boolean variables
    extra_code = """// # Extra Complex Valid Logic
// Logline: Deep nesting and parenthesized logic
// Setup: Pure compute
// Beats:
//   1. Run checks
fn check_deep(a: Int, b: Int, c: Int) -> Bool {
    return ((a > 0) && (b < 10)) || (((c == 5) && (a != 2)) || ((b == 0) && (c > 0)));
}
pub fn main() -> Int {
    let t1: Bool = check_deep(1, 5, 0);
    let t2: Bool = check_deep(-1, 20, 5);
    let t3: Bool = check_deep(-1, 0, 10);
    let f1: Bool = check_deep(-1, 20, 0);
    if t1 && t2 && t3 && !f1 {
        println("ALL_PASSED");
        return 0;
    }
    return 1;
}
"""
    with tempfile.NamedTemporaryFile(suffix=".oo", mode="w", delete=False) as f:
        f.write(extra_code)
        src_path = f.name
    try:
        p_chk = run_cmd([OODAC, "check", src_path])
        if p_chk.returncode != 0:
            print(f"  FAIL check on deep logic: {p_chk.stderr}")
            return False
        p_emit = run_cmd([OODAC, "emit-llvm", src_path])
        if p_emit.returncode != 0:
            print(f"  FAIL emit-llvm on deep logic: {p_emit.stderr}")
            return False
        ll_path = src_path + ".ll"
        with open(ll_path, "w") as f:
            f.write(p_emit.stdout)
        bin_path = src_path + "_bin"
        p_clang = run_cmd(["clang", "-O2", ll_path, LIBOODAR, "-lm", "-lpthread", "-o", bin_path])
        if p_clang.returncode != 0:
            print(f"  FAIL clang build: {p_clang.stderr}")
            return False
        p_run = run_cmd([bin_path])
        if p_run.stdout.strip() != "ALL_PASSED":
            print(f"  FAIL expected ALL_PASSED, got '{p_run.stdout.strip()}'")
            return False
        print("  [OK] Deeply nested valid logic compiled and verified.")
    finally:
        for p in [src_path, src_path + ".art", src_path + ".ll", src_path + "_bin"]:
            if os.path.exists(p): os.unlink(p)

    return True

def main():
    print("=== Adversarial Challenge: Logical Operator Type Soundness ===")
    neg_ok = test_negative_cases()
    pos_ok = test_positive_complex_cases()
    if neg_ok and pos_ok:
        print("=== Task 1 PASSED: Logical Operator Type Soundness is 100% Robust ===")
        sys.exit(0)
    else:
        print("=== Task 1 FAILED ===")
        sys.exit(1)

if __name__ == "__main__":
    main()
