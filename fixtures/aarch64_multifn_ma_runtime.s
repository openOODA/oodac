.text
.globl multiply_add
.p2align 2
multiply_add:
    mul x0, x0, x1
    add x0, x0, x2
    ret
