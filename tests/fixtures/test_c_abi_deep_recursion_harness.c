#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

typedef struct {
    int64_t x;
    int64_t y;
} Point;

typedef struct {
    int32_t tag;
    Point val;
} OoOpt_St_Point;

typedef struct {
    int64_t id;
    int64_t score;
} MyStruct;

typedef struct {
    int32_t tag;
    MyStruct val;
    struct { const char *data; int64_t len; } err;
} OoRes_St_MyStruct;

// SysV AMD64 ABI declarations
extern void c_export_deep_opt(OoOpt_St_Point *ret, int64_t depth);
extern void c_export_deep_res(OoRes_St_MyStruct *ret, int64_t depth);

int main(void) {
    // Canary-guarded caller stack frame
    struct {
        int64_t canary_top;
        OoOpt_St_Point opt_pt;
        int64_t canary_mid;
        OoRes_St_MyStruct res_st;
        int64_t canary_bot;
    } frame;

    frame.canary_top = 0x1122334455667788LL;
    frame.canary_mid = 0x2233445566778899LL;
    frame.canary_bot = 0x33445566778899AALL;

    // Test 1: Deep recursion depth 1000 returning Option[Point]
    memset(&frame.opt_pt, 0xAA, sizeof(frame.opt_pt));
    c_export_deep_opt(&frame.opt_pt, 1000);

    if (frame.canary_top != 0x1122334455667788LL) {
        fprintf(stderr, "FAIL: canary_top corrupted after c_export_deep_opt: 0x%lx\n", (long)frame.canary_top);
        return 1;
    }
    if (frame.canary_mid != 0x2233445566778899LL) {
        fprintf(stderr, "FAIL: canary_mid corrupted after c_export_deep_opt: 0x%lx\n", (long)frame.canary_mid);
        return 2;
    }
    if (frame.opt_pt.tag != 1 || frame.opt_pt.val.x != 2010 || frame.opt_pt.val.y != 3020) {
        fprintf(stderr, "FAIL: opt_pt tag=%d x=%ld y=%ld\n",
                frame.opt_pt.tag, (long)frame.opt_pt.val.x, (long)frame.opt_pt.val.y);
        return 3;
    }

    // Test 2: Deep recursion depth 1000 returning Result[MyStruct, String]
    memset(&frame.res_st, 0x55, sizeof(frame.res_st));
    c_export_deep_res(&frame.res_st, 1000);

    if (frame.canary_mid != 0x2233445566778899LL) {
        fprintf(stderr, "FAIL: canary_mid corrupted after c_export_deep_res: 0x%lx\n", (long)frame.canary_mid);
        return 4;
    }
    if (frame.canary_bot != 0x33445566778899AALL) {
        fprintf(stderr, "FAIL: canary_bot corrupted after c_export_deep_res: 0x%lx\n", (long)frame.canary_bot);
        return 5;
    }
    if (frame.res_st.tag != 1 || frame.res_st.val.id != 1100 || frame.res_st.val.score != 10500) {
        fprintf(stderr, "FAIL: res_st tag=%d id=%ld score=%ld\n",
                frame.res_st.tag, (long)frame.res_st.val.id, (long)frame.res_st.val.score);
        return 6;
    }

    printf("C_ABI_DEEP_RECURSION_PASS\n");
    return 0;
}
