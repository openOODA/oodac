#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <limits.h>

// Prototypes for Ooda exported functions
uint32_t add_numbers(uint32_t a, uint32_t b);
int32_t mul_numbers(int32_t a, int32_t b);

int main(void) {
    // 1. Basic addition
    assert(add_numbers(10, 20) == 30);
    // 2. Boundary addition: 0 + 0, 0 + max, overflow wrap
    assert(add_numbers(0, 0) == 0);
    assert(add_numbers(0, UINT32_MAX) == UINT32_MAX);
    assert(add_numbers(UINT32_MAX, 1) == 0); // 32-bit unsigned wrap
    assert(add_numbers(1000000000U, 2000000000U) == 3000000000U);

    // 3. Multiplication: positive, negative, zero, boundary
    assert(mul_numbers(6, 7) == 42);
    assert(mul_numbers(-6, 7) == -42);
    assert(mul_numbers(-6, -7) == 42);
    assert(mul_numbers(0, 1000) == 0);
    assert(mul_numbers(1, -1) == -1);
    assert(mul_numbers(32767, -2) == -65534);

    printf("ALL_CALL_TESTS_PASS\n");
    return 0;
}
