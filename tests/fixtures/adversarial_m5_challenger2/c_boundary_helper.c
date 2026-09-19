#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>

struct OoOpt_Ptr {
    int32_t tag;
    void *ptr;
};

// C callee returning Option[&Int] via sret
void oo_c_get_val(struct OoOpt_Ptr *ret, int64_t *val) {
    if (val != NULL) {
        ret->tag = 1;
        ret->ptr = val;
    } else {
        ret->tag = 0;
        ret->ptr = NULL;
    }
}

// C callee consuming Option[&Int] passed by value
int64_t oo_c_consume_val(struct OoOpt_Ptr opt) {
    if (opt.tag != 0 && opt.ptr != NULL) {
        return *(int64_t *)opt.ptr;
    }
    return 0;
}
