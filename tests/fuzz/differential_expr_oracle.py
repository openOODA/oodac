#!/usr/bin/env python3
"""Differential Expression Generator and Reference Oracle.
Generates valid compound openOODA expressions and reference outputs.
Compliance: wc -l <= 256.
"""
import sys, random

I64_MIN, I64_MAX = -9223372036854775808, 9223372036854775807

def to_i64(v):
    return ((v + (1 << 63)) % (1 << 64)) - (1 << 63)

def c_div(a, b):
    if a == I64_MIN and b == -1: return I64_MIN
    sign = -1 if (a < 0) ^ (b < 0) else 1
    return sign * (abs(a) // abs(b))

def c_rem(a, b):
    if a == I64_MIN and b == -1: return 0
    sign = -1 if a < 0 else 1
    return sign * (abs(a) % abs(b))

class Node: pass

class IntLit(Node):
    def __init__(self, v): self.v = v
    def to_oo(self, p=False): return str(self.v)
    def eval(self): return self.v

class IntNeg(Node):
    def __init__(self, e): self.e = e
    def to_oo(self, p=False): return f"(-{self.e.to_oo(True)})"
    def eval(self): return to_i64(-self.e.eval())

class IntBin(Node):
    def __init__(self, op, l, r): self.op, self.l, self.r = op, l, r
    def to_oo(self, p=False):
        s = f"{self.l.to_oo(True)} {self.op} {self.r.to_oo(True)}"
        return f"({s})" if p else s
    def eval(self):
        l, r = self.l.eval(), self.r.eval()
        if self.op == '+': return to_i64(l + r)
        if self.op == '-': return to_i64(l - r)
        if self.op == '*': return to_i64(l * r)
        if self.op == '/': return c_div(l, r)
        if self.op == '%': return c_rem(l, r)
        if self.op == '&': return to_i64(l & r)
        if self.op == '|': return to_i64(l | r)
        if self.op == '^': return to_i64(l ^ r)
        if self.op == '<<': return to_i64(l << (r & 63))
        if self.op == '>>': return to_i64(l >> (r & 63))
        raise ValueError(self.op)

class IfExpr(Node):
    def __init__(self, c, t, e): self.c, self.t, self.e = c, t, e
    def to_oo(self, p=False):
        # Strict Academy Law: Zero condition outer parentheses!
        s = f"if {self.c.to_oo(False)} {{ {self.t.to_oo(False)} }} else {{ {self.e.to_oo(False)} }}"
        return f"({s})" if p else s
    def eval(self): return self.t.eval() if self.c.eval() else self.e.eval()

class BoolLit(Node):
    def __init__(self, v): self.v = v
    def to_oo(self, p=False): return "true" if self.v else "false"
    def eval(self): return self.v

class BoolNot(Node):
    def __init__(self, e): self.e = e
    def to_oo(self, p=False):
        inner = self.e.to_oo(False)
        s = f"!({inner})" if isinstance(self.e, (BoolBin, CmpBin)) else f"!{inner}"
        return f"({s})" if p else s
    def eval(self): return not self.e.eval()

class BoolBin(Node):
    def __init__(self, op, l, r): self.op, self.l, self.r = op, l, r
    def to_oo(self, p=False):
        l_str = self.l.to_oo(True) if isinstance(self.l, BoolBin) else self.l.to_oo(False)
        r_str = self.r.to_oo(True) if isinstance(self.r, BoolBin) else self.r.to_oo(False)
        s = f"{l_str} {self.op} {r_str}"
        return f"({s})" if p else s
    def eval(self):
        l = self.l.eval()
        return (l and self.r.eval()) if self.op == '&&' else (l or self.r.eval())

class CmpBin(Node):
    def __init__(self, op, l, r): self.op, self.l, self.r = op, l, r
    def to_oo(self, p=False):
        s = f"{self.l.to_oo(True)} {self.op} {self.r.to_oo(True)}"
        return f"({s})" if p else s
    def eval(self):
        l, r = self.l.eval(), self.r.eval()
        if self.op == '<': return l < r
        if self.op == '<=': return l <= r
        if self.op == '>': return l > r
        if self.op == '>=': return l >= r
        if self.op == '==': return l == r
        if self.op == '!=': return l != r
        raise ValueError(self.op)

EDGES = [0, 1, -1, 2, -2, 63, 64, 127, 128, 2147483647, -2147483648, I64_MAX, I64_MIN]

def gen_int(rng, d, max_d, non_zero=False):
    if d >= max_d:
        v = rng.choice([x for x in EDGES if not non_zero or x != 0] if rng.random() < 0.4
                       else [x for x in range(-50, 51) if not non_zero or x != 0])
        return IntLit(v)
    pick = rng.randint(0, 9)
    if pick == 0 and not non_zero:
        return IntNeg(gen_int(rng, d + 1, max_d))
    if pick == 1 and not non_zero:
        return IfExpr(gen_bool(rng, d + 1, max_d, True), gen_int(rng, d + 1, max_d),
                      gen_int(rng, d + 1, max_d))
    ops = ['+', '-', '*', '/', '%', '&', '|', '^', '<<', '>>']
    op = rng.choice(ops)
    l = gen_int(rng, d + 1, max_d)
    r = gen_int(rng, d + 1, max_d, non_zero=(op in ('/', '%')))
    node = IntBin(op, l, r)
    if non_zero and node.eval() == 0:
        return IntBin('+', node, IntLit(1))
    return node

def gen_bool(rng, d, max_d, is_cond_root=False):
    if d >= max_d: return BoolLit(rng.choice([True, False]))
    pick = rng.randint(0, 4)
    if pick == 0: return BoolLit(rng.choice([True, False]))
    if pick == 1: return BoolNot(gen_bool(rng, d + 1, max_d, False))
    if pick == 2 and not is_cond_root:
        return BoolBin(rng.choice(['&&', '||']),
                       gen_bool(rng, d + 1, max_d, False),
                       gen_bool(rng, d + 1, max_d, False))
    op = rng.choice(['<', '<=', '>', '>=', '==', '!='])
    if is_cond_root:
        l = IntLit(rng.choice(EDGES))
    else:
        l = gen_int(rng, d + 1, max_d)
    r = gen_int(rng, d + 1, max_d)
    return CmpBin(op, l, r)

def gen_batch(seed, count, oo_path, exp_path):
    rng = random.Random(seed)
    specials = [
        IntBin('/', IntLit(I64_MIN), IntLit(-1)),
        IntBin('%', IntLit(I64_MIN), IntLit(-1)),
        IntBin('<<', IntLit(1), IntLit(64)),
        IntBin('<<', IntLit(1), IntLit(65)),
        IntBin('<<', IntLit(1), IntLit(-1)),
        IntBin('>>', IntLit(-16), IntLit(2)),
        IntBin('>>', IntLit(-16), IntLit(66)),
    ]
    cases = []
    for s in specials:
        if len(cases) < count: cases.append(s)
    while len(cases) < count:
        cases.append(gen_int(rng, 0, rng.randint(1, 3)))
    with open(oo_path, 'w') as f_oo, open(exp_path, 'w') as f_exp:
        f_oo.write("// # Differential Expression Batch\n")
        f_oo.write("// Logline: Auto-generated compound expression batch\n")
        f_oo.write("// Setup: Verified against reference mathematical oracle\n")
        f_oo.write("// Beats:\n//   1. Execute batch expressions and print results\n")
        f_oo.write("pub fn main() -> Int {\n")
        for i, c in enumerate(cases):
            f_oo.write(f"    let v{i}: Int = {c.to_oo(False)};\n")
            f_oo.write(f"    println(v{i}.to_string());\n")
            f_exp.write(f"{c.eval()}\n")
        f_oo.write("    return 0;\n}\n")

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Usage: differential_expr_oracle.py <seed> <count> <out.oo> <out.exp>")
        sys.exit(1)
    gen_batch(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3], sys.argv[4])
