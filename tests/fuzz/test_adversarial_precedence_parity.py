#!/usr/bin/env python3
"""Adversarial challenger: Oracle Precedence Parity & Deep AST Verification.
Stresses Finding 2 remediation: verifies compound comparisons, bitwise ops,
deep AST nesting (depth >= 5), and boundary integers (INT64_MAX, INT64_MIN, etc.).
Asserts 0 mismatches between Python oracle and compiled openOODA binary.
Compliance: wc -l <= 256.
"""
import os, random, subprocess, sys, tempfile
from differential_expr_oracle import (
    to_i64, c_div, c_rem, I64_MIN, I64_MAX,
    IntLit, IntNeg, IntBin, BoolLit, BoolNot, BoolBin, CmpBin, IfExpr,
    gen_int, gen_bool
)

OODAC = os.path.expanduser("~/.openooda/bin/oodac")
LIBOODAR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../../../oodar/liboodar.a")
)
os.environ["OO_LIST_AMBIENT_QUOTA"] = "34359738368"
os.environ["OODA_NO_JAIL"] = "1"

def run_cmd(cmd, timeout=60.0):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)

def test_targeted_precedence_nodes():
    print(">>> [Task 2.1] Targeted Precedence Nodes (Bitwise vs Comparison in AST)...")
    # (-14 & 25) > 10
    n1 = IfExpr(CmpBin('>', IntBin('&', IntLit(-14), IntLit(25)), IntLit(10)), IntLit(1), IntLit(0))
    # (7 | 8) == 15
    n2 = IfExpr(CmpBin('==', IntBin('|', IntLit(7), IntLit(8)), IntLit(15)), IntLit(1), IntLit(0))
    # (123 ^ 456) <= 500
    n3 = IfExpr(CmpBin('<=', IntBin('^', IntLit(123), IntLit(456)), IntLit(500)), IntLit(1), IntLit(0))
    # Complex combination: ((a & b) > 0) && ((c | d) == 15)
    cmp_a = CmpBin('>', IntBin('&', IntLit(30), IntLit(15)), IntLit(0))
    cmp_b = CmpBin('==', IntBin('|', IntLit(7), IntLit(8)), IntLit(15))
    n4 = IfExpr(BoolBin('&&', cmp_a, cmp_b), IntLit(100), IntLit(200))
    # Boundary extremes
    n5 = IfExpr(CmpBin('<', IntLit(I64_MIN), IntLit(I64_MAX)), IntLit(42), IntLit(-42))
    n6 = IntBin('/', IntLit(I64_MIN), IntLit(-1)) # overflow trap defense
    n7 = IntBin('%', IntLit(I64_MIN), IntLit(-1))
    n8 = IntBin('<<', IntLit(1), IntLit(63))
    n9 = IntBin('>>', IntLit(I64_MIN), IntLit(63))

    targeted = [n1, n2, n3, n4, n5, n6, n7, n8, n9]
    return verify_nodes_against_compiled("targeted_precedence", targeted)

def test_deep_ast_batches(num_batches=5, batch_size=20):
    print(f">>> [Task 2.2] Deep AST Batches (depth >= 5, boundary integers)...")
    rng = random.Random(1337)
    all_ok = True
    for b in range(num_batches):
        depth = 5 + (b % 3) # depth 5, 6, 7
        nodes = []
        for _ in range(batch_size):
            node = gen_int(rng, 0, depth)
            nodes.append(node)
        ok = verify_nodes_against_compiled(f"batch_depth_{depth}_b{b}", nodes)
        if not ok:
            all_ok = False
            break
    return all_ok

def verify_nodes_against_compiled(tag, nodes):
    with tempfile.TemporaryDirectory() as td:
        src_path = os.path.join(td, f"{tag}.oo")
        ll_path = os.path.join(td, f"{tag}.ll")
        bin_path = os.path.join(td, f"{tag}_bin")

        expected_outputs = []
        with open(src_path, "w") as f:
            f.write("// # Parity Test\n")
            f.write("// Logline: Challenger verification\n")
            f.write("// Setup: Differential\n")
            f.write("// Beats:\n//   1. Run expressions\n")
            f.write("pub fn main() -> Int {\n")
            for i, n in enumerate(nodes):
                oo_code = n.to_oo(False)
                expected_val = n.eval()
                expected_outputs.append(str(expected_val))
                f.write(f"    let v{i}: Int = {oo_code};\n")
                f.write(f"    println(v{i}.to_string());\n")
            f.write("    return 0;\n}\n")

        p_chk = run_cmd([OODAC, "check", src_path])
        if p_chk.returncode != 0:
            print(f"  FAIL [{tag}] check: rc={p_chk.returncode}\n{p_chk.stdout}\n{p_chk.stderr}")
            return False

        p_emit = run_cmd([OODAC, "emit-llvm", src_path])
        if p_emit.returncode != 0:
            print(f"  FAIL [{tag}] emit-llvm: rc={p_emit.returncode}\n{p_emit.stderr}")
            return False

        with open(ll_path, "w") as f:
            f.write(p_emit.stdout)

        p_clang = run_cmd(["clang", "-O2", ll_path, LIBOODAR, "-lm", "-lpthread", "-o", bin_path])
        if p_clang.returncode != 0:
            print(f"  FAIL [{tag}] clang build: rc={p_clang.returncode}\n{p_clang.stderr}")
            return False

        p_run = run_cmd([bin_path])
        if p_run.returncode != 0:
            print(f"  FAIL [{tag}] execution: rc={p_run.returncode}")
            return False

        actual_outputs = p_run.stdout.strip().splitlines()
        if len(actual_outputs) != len(expected_outputs):
            print(f"  FAIL [{tag}] line count mismatch: expected {len(expected_outputs)}, got {len(actual_outputs)}")
            return False

        mismatches = 0
        for i, (exp, act) in enumerate(zip(expected_outputs, actual_outputs)):
            if exp != act:
                print(f"  MISMATCH [{tag}] expr #{i}: expected {exp}, got {act}")
                mismatches += 1

        if mismatches > 0:
            print(f"  FAIL [{tag}] {mismatches} mismatches found!")
            return False

        print(f"  [OK] [{tag}] {len(nodes)} expressions verified: 0 mismatches with python oracle.")
        return True

def main():
    print("=== Adversarial Challenge: Oracle Precedence Parity ===")
    t1_ok = test_targeted_precedence_nodes()
    t2_ok = test_deep_ast_batches(num_batches=6, batch_size=15)
    if t1_ok and t2_ok:
        print("=== Task 2 PASSED: 0 Mismatches Across All Targeted and Deep Expressions ===")
        sys.exit(0)
    else:
        print("=== Task 2 FAILED ===")
        sys.exit(1)

if __name__ == "__main__":
    main()
