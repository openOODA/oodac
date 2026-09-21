#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

typedef struct {
    int64_t id;
    int64_t score;
} MyStruct;

typedef struct {
    int32_t tag;
    MyStruct val;
} OoOpt_St_MyStruct;

typedef struct {
    int32_t tag;
    MyStruct val;
    struct { const char *data; int64_t len; } err;
} OoRes_St_MyStruct;

typedef struct {
    int32_t tag;
    void *ptr;
} OoOpt_Ptr;

// SysV AMD64 ABI declarations
extern void c_export_make_opt(OoOpt_St_MyStruct *ret, bool flag);
extern void c_export_make_res(OoRes_St_MyStruct *ret, bool flag);
extern void c_export_opt_ref(OoOpt_Ptr *ret, bool flag, const MyStruct *s);

int main(void) {
    // 1. Test Option[MyStruct] Some
    OoOpt_St_MyStruct o1;
    memset(&o1, 0xAA, sizeof(o1));
    c_export_make_opt(&o1, true);
    if (o1.tag != 1 || o1.val.id != 42 || o1.val.score != 999) {
        fprintf(stderr, "FAIL: c_export_make_opt(true) tag=%d id=%ld score=%ld\n",
                o1.tag, (long)o1.val.id, (long)o1.val.score);
        return 1;
    }

    // 2. Test Option[MyStruct] None
    OoOpt_St_MyStruct o2;
    memset(&o2, 0x55, sizeof(o2));
    c_export_make_opt(&o2, false);
    if (o2.tag != 0) {
        fprintf(stderr, "FAIL: c_export_make_opt(false) tag=%d\n", o2.tag);
        return 2;
    }

    // 3. Test Result[MyStruct, String] Ok
    OoRes_St_MyStruct r1;
    memset(&r1, 0xAA, sizeof(r1));
    c_export_make_res(&r1, true);
    if (r1.tag != 1 || r1.val.id != 84 || r1.val.score != 1998) {
        fprintf(stderr, "FAIL: c_export_make_res(true) tag=%d id=%ld score=%ld\n",
                r1.tag, (long)r1.val.id, (long)r1.val.score);
        return 3;
    }

    // 4. Test Result[MyStruct, String] Err
    OoRes_St_MyStruct r2;
    memset(&r2, 0x55, sizeof(r2));
    c_export_make_res(&r2, false);
    if (r2.tag != 0 || r2.err.len != 19 || strncmp(r2.err.data, "foreign call failed", 19) != 0) {
        fprintf(stderr, "FAIL: c_export_make_res(false) tag=%d err=%.*s\n",
                r2.tag, (int)r2.err.len, r2.err.data);
        return 4;
    }

    // 5. Test Option[&MyStruct] niche pointer Some
    MyStruct st = { .id = 1234, .score = 5678 };
    OoOpt_Ptr nr1;
    memset(&nr1, 0xAA, sizeof(nr1));
    c_export_opt_ref(&nr1, true, &st);
    if (nr1.tag != 1 || nr1.ptr != &st) {
        fprintf(stderr, "FAIL: c_export_opt_ref(true) tag=%d ptr=%p expected=%p\n",
                nr1.tag, nr1.ptr, (void*)&st);
        return 5;
    }

    // 6. Test Option[&MyStruct] niche pointer None
    OoOpt_Ptr nr2;
    memset(&nr2, 0x55, sizeof(nr2));
    c_export_opt_ref(&nr2, false, &st);
    if (nr2.tag != 0 || nr2.ptr != NULL) {
        fprintf(stderr, "FAIL: c_export_opt_ref(false) tag=%d ptr=%p\n",
                nr2.tag, nr2.ptr);
        return 6;
    }

    // 7. Stress loop: 1000 calls across SysV ABI boundary
    for (int i = 0; i < 1000; i++) {
        OoOpt_St_MyStruct so;
        c_export_make_opt(&so, (i % 2 == 0));
        if (i % 2 == 0) {
            if (so.tag != 1 || so.val.id != 42) return 7;
        } else {
            if (so.tag != 0) return 8;
        }

        OoOpt_Ptr sp;
        c_export_opt_ref(&sp, (i % 2 == 1), &st);
        if (i % 2 == 1) {
            if (sp.tag != 1 || sp.ptr != &st) return 9;
        } else {
            if (sp.tag != 0 || sp.ptr != NULL) return 10;
        }
    }

    printf("C_ABI_FOREIGN_HARNESS_PASS\n");
    return 0;
}
