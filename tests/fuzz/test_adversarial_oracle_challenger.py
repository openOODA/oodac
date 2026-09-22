#!/usr/bin/env python3
"""Adversarial challenger for Differential Expression Oracle.
Cross-verifies Python math oracle against C/LLVM two's complement semantics,
including INT64_MIN / -1, INT64_MIN % -1, sign-extended shifts, and short-circuiting.
Compliance: wc -l <= 256.
"""
import sys, subprocess, tempfile, os
from differential_expr_oracle import (
    to_i64, c_div, c_rem, I64_MIN, I64_MAX,
    IntBin, IntLit, BoolBin, BoolLit, IfExpr
)

def verify_oracle_arithmetic_unit():
    print(">>> [Challenger Unit 1] Verifying INT64_MIN / -1 and % -1...")
    assert c_div(I64_MIN, -1) == I64_MIN, f"div failed: {c_div(I64_MIN, -1)}"
    assert c_rem(I64_MIN, -1) == 0, f"rem failed: {c_rem(I64_MIN, -1)}"
    assert c_div(I64_MIN, 1) == I64_MIN, f"div 1 failed: {c_div(I64_MIN, 1)}"
    assert c_div(I64_MIN, I64_MIN) == 1, f"div self failed: {c_div(I64_MIN, I64_MIN)}"
    assert c_div(-7, 2) == -3, f"trunc div pos failed: {c_div(-7, 2)}"
    assert c_div(7, -2) == -3, f"trunc div neg failed: {c_div(7, -2)}"
    assert c_div(-7, -2) == 3, f"trunc div both failed: {c_div(-7, -2)}"
    assert c_rem(-7, 2) == -1, f"trunc rem pos failed: {c_rem(-7, 2)}"
    assert c_rem(7, -2) == 1, f"trunc rem neg failed: {c_rem(7, -2)}"
    assert c_rem(-7, -2) == -1, f"trunc rem both failed: {c_rem(-7, -2)}"
    print("    Unit 1 PASS: Division/modulo semantics match C/LLVM.")

def verify_oracle_shifts_unit():
    print(">>> [Challenger Unit 2] Verifying bitwise shifts & sign extension...")
    shift_cases = [
        (-16, 2, -4),
        (-16, 66, -4), # 66 & 63 = 2
        (-1, 63, -1),
        (-1, -1, -1),  # -1 & 63 = 63
        (I64_MIN, 63, -1),
        (I64_MIN, 1, -4611686018427387904),
        (I64_MIN, 64, I64_MIN), # 64 & 63 = 0
        (-100, -1, -1), # -1 & 63 = 63 -> -100 >> 63 = -1
    ]
    for val, sh, exp in shift_cases:
        actual = IntBin('>>', IntLit(val), IntLit(sh)).eval()
        assert actual == exp, f"Shift >> failed for ({val}, {sh}): {actual} != {exp}"

    shl_cases = [
        (1, 64, 1),
        (1, 65, 2),
        (-5, 2, -20),
        (1, -1, to_i64(1 << 63)),
    ]
    for val, sh, exp in shl_cases:
        actual = IntBin('<<', IntLit(val), IntLit(sh)).eval()
        assert actual == exp, f"Shift << failed for ({val}, {sh}): {actual} != {exp}"
    print("    Unit 2 PASS: Shift masking & sign extension match C/LLVM.")

def verify_oracle_short_circuit_unit():
    print(">>> [Challenger Unit 3] Verifying logical short-circuiting...")
    # In BoolBin, if lhs is false, rhs is NOT evaluated.
    class TrappingNode:
        def to_oo(self, p=False): return "false"
        def eval(self): raise RuntimeError("RHS evaluated when it should short-circuit!")

    node_and = BoolBin('&&', BoolLit(False), TrappingNode())
    assert node_and.eval() is False, "False && <trap> failed"

    node_or = BoolBin('||', BoolLit(True), TrappingNode())
    assert node_or.eval() is True, "True || <trap> failed"
    print("    Unit 3 PASS: Short-circuiting prevents RHS evaluation.")

def verify_oracle_div_zero_guard_unit():
    print(">>> [Challenger Unit 4] Verifying division by zero guards...")
    # 4.1 Oracle raises ZeroDivisionError on b=0
    try:
        c_div(42, 0)
        assert False, "c_div(42, 0) should have raised ZeroDivisionError"
    except ZeroDivisionError:
        pass

    try:
        c_rem(42, 0)
        assert False, "c_rem(42, 0) should have raised ZeroDivisionError"
    except ZeroDivisionError:
        pass

    # 4.2 Generator non-zero guarantee across 50,000 expressions
    from differential_expr_oracle import gen_int
    import random
    rng = random.Random(777)
    for _ in range(50000):
        node = gen_int(rng, 0, 3)
        # eval() must never raise ZeroDivisionError
        _ = node.eval()

    # 4.3 Native compiler exits fail-closed with code 1 on div-by-zero
    oodac_bin = os.environ.get("OODAC_BIN", os.path.expanduser("~/.openooda/bin/oodac"))
    with tempfile.TemporaryDirectory() as td:
        src = os.path.join(td, "div0.oo")
        bin_path = os.path.join(td, "div0_bin")
        with open(src, "w") as f:
            f.write("// # Div Zero\n// Logline: Test div zero\n// Setup: pure\n// Beats: B\n")
            f.write("pub fn main() -> Int {\n    let a: Int = 100;\n    let b: Int = 0;\n    return a / b;\n}\n")
        res = subprocess.run([oodac_bin, "build", src, "-o", bin_path], capture_output=True)
        assert res.returncode == 0, f"Compilation failed: {res.stderr}"
        run_res = subprocess.run([bin_path], capture_output=True)
        assert run_res.returncode == 1, f"Expected rc 1 on div-by-zero, got {run_res.returncode}"
    print("    Unit 4 PASS: Division by zero guards verified (oracle + native).")

def main():
    print("=== Adversarial Challenge: Differential Expression Oracle ===")
    verify_oracle_arithmetic_unit()
    verify_oracle_shifts_unit()
    verify_oracle_short_circuit_unit()
    verify_oracle_div_zero_guard_unit()
    print("=== All Oracle Adversarial Units PASSED (4/4) ===")

if __name__ == '__main__':
    main()
