/* Deep Substrate Physics M1 Iteration 2 Stress Test:
 * Float List (OoFList) 10k In-Place / COW / Double Precision &
 * 2D Matrix Slices (OoLL_I / OoLL_S) Exact ARC Retain/Release Verification */

#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include "oodar.h"

extern long long oo_list_ambient_bytes;

static OoFList sim_flist_push(OoFList l, double v) {
  OoFList old = l;
  OoFList ret = oo_flist_push(l, v);
  oo_flist_release(old);
  return ret;
}

static OoFList sim_flist_set(OoFList l, long long i, double v) {
  OoFList old = l;
  OoFList ret = oo_flist_set(l, i, v);
  oo_flist_release(old);
  return ret;
}

static OoIList sim_ilist_push(OoIList l, long long v) {
  OoIList old = l;
  OoIList ret = oo_ilist_push(l, v);
  oo_ilist_release(old);
  return ret;
}

static OoSList sim_slist_push(OoSList l, OoStr v) {
  OoSList old = l;
  OoSList ret = oo_slist_push(l, v);
  oo_slist_release(old);
  return ret;
}

static void test_flist_inplace_10k_physics(void) {
  long long bytes_before = oo_list_ambient_bytes;
  OoFList fl = oo_flist_new();
  for (long long i = 0; i < 16; i++) {
    fl = sim_flist_push(fl, (double)i * 1.25);
  }
  void *orig_data = fl.data;
  OoListHeader *h0 = ((OoListHeader *)fl.data) - 1;
  assert(h0->ref_count == 1);
  long long bytes_after_push = oo_list_ambient_bytes;

  /* 10,000 in-place mutations asserting bit-identical data pointer and rc=1 */
  for (long long k = 0; k < 10000; k++) {
    long long idx = k % 16;
    double expected = (double)k * 3.141592653589793;
    fl = sim_flist_set(fl, idx, expected);
    assert(fl.data == orig_data); /* ZERO REALLOCATIONS */
    assert(fl.data[idx] == expected);
    OoListHeader *hk = ((OoListHeader *)fl.data) - 1;
    assert(hk->ref_count == 1); /* REFCOUNT STAYS STRICTLY 1 */
    assert(oo_list_ambient_bytes == bytes_after_push); /* CONSTANT MEMORY FOOTPRINT */
  }
  oo_flist_release(fl);
  assert(oo_list_ambient_bytes == bytes_before); /* ZERO LEAKS */
}

static void test_flist_cow_and_precision_physics(void) {
  long long bytes_before = oo_list_ambient_bytes;
  OoFList a = oo_flist_new();
  double test_vals[6] = {
    1.0000000000000002,
    9007199254740991.0,
    3.141592653589793238,
    2.718281828459045235,
    -987654.321012345,
    1.0 / 3.0
  };
  for (int i = 0; i < 6; i++) a = sim_flist_push(a, test_vals[i]);

  /* 1. Precision preservation across push and slice */
  OoFList sl = oo_flist_slice(a, 0, 6);
  assert(sl.len == 6);
  for (int i = 0; i < 6; i++) {
    assert(memcmp(&sl.data[i], &test_vals[i], sizeof(double)) == 0);
  }
  oo_flist_release(sl);

  /* 2. Alternating COW isolation */
  for (long long k = 0; k < 1000; k++) {
    oo_flist_retain(a);
    OoListHeader *ha = ((OoListHeader *)a.data) - 1;
    assert(ha->ref_count == 2);

    double b_val = (double)k * 100.5;
    OoFList b_mod = oo_flist_set(a, 0, b_val);
    assert(b_mod.data != a.data); /* Disjoint buffers */
    assert(a.data[0] == test_vals[0]); /* Original unmodified */
    assert(b_mod.data[0] == b_val);

    oo_flist_release(a);
    assert(ha->ref_count == 1);
    OoListHeader *hb = ((OoListHeader *)b_mod.data) - 1;
    assert(hb->ref_count == 1);

    oo_flist_release(b_mod);
  }
  oo_flist_release(a);
  assert(oo_list_ambient_bytes == bytes_before);
}

static void test_2d_matrix_slice_exact_arc_physics(void) {
  long long bytes_before = oo_list_ambient_bytes;
  OoLL_I m = oo_ll_I_new();
  for (int r = 0; r < 4; r++) {
    OoIList row = oo_ilist_new();
    for (int c = 0; c < 4; c++) row = sim_ilist_push(row, r * 10 + c);
    OoLL_I old_m = m;
    m = oo_ll_I_push(m, row);
    oo_ll_I_release(old_m);
    oo_ilist_release(row);
  }

  OoListHeader *h0 = ((OoListHeader *)m.data[0].data) - 1;
  OoListHeader *h1 = ((OoListHeader *)m.data[1].data) - 1;
  OoListHeader *h2 = ((OoListHeader *)m.data[2].data) - 1;
  OoListHeader *h3 = ((OoListHeader *)m.data[3].data) - 1;

  /* Before slice: all inner rows have refcount == 1 */
  assert(h0->ref_count == 1);
  assert(h1->ref_count == 1);
  assert(h2->ref_count == 1);
  assert(h3->ref_count == 1);

  /* Slice rows 1..3 (exclusive) -> rows 1 and 2 */
  OoLL_I s = oo_ll_I_slice(m, 1, 3);
  assert(s.len == 2);
  assert(h0->ref_count == 1); /* Non-sliced stays 1 */
  assert(h1->ref_count == 2); /* Sliced retains to 2 */
  assert(h2->ref_count == 2); /* Sliced retains to 2 */
  assert(h3->ref_count == 1); /* Non-sliced stays 1 */

  /* Slice of slice: slice s at [1, 2) -> row 2 */
  OoLL_I s2 = oo_ll_I_slice(s, 1, 2);
  assert(s2.len == 1);
  assert(h1->ref_count == 2);
  assert(h2->ref_count == 3); /* Sliced again retains to 3 */

  /* Release s2 */
  oo_ll_I_release(s2);
  assert(h1->ref_count == 2);
  assert(h2->ref_count == 2); /* Returns to 2 */

  /* Release s */
  oo_ll_I_release(s);
  assert(h0->ref_count == 1);
  assert(h1->ref_count == 1); /* Returns to 1 */
  assert(h2->ref_count == 1); /* Returns to 1 */
  assert(h3->ref_count == 1);

  /* 10,000 slice iterations loop asserting ZERO leak */
  long long bytes_with_m = oo_list_ambient_bytes;
  for (int k = 0; k < 10000; k++) {
    OoLL_I s_loop = oo_ll_I_slice(m, 1, 3);
    assert(s_loop.len == 2);
    oo_ll_I_release(s_loop);
    assert(oo_list_ambient_bytes == bytes_with_m);
  }

  oo_ll_I_release(m);
  assert(oo_list_ambient_bytes == bytes_before); /* All memory reclaimed */
}

static void test_2d_string_matrix_slice_physics(void) {
  long long bytes_before = oo_list_ambient_bytes;
  OoLL_S ms = oo_ll_S_new();
  for (int r = 0; r < 4; r++) {
    OoSList row = oo_slist_new();
    row = sim_slist_push(row, oo_str_lit("alpha"));
    row = sim_slist_push(row, oo_str_lit("beta"));
    OoLL_S old_ms = ms;
    ms = oo_ll_S_push(ms, row);
    oo_ll_S_release(old_ms);
    oo_slist_release(row);
  }

  long long bytes_with_ms = oo_list_ambient_bytes;
  for (int k = 0; k < 5000; k++) {
    OoLL_S sl = oo_ll_S_slice(ms, 1, 3);
    assert(sl.len == 2);
    oo_ll_S_release(sl);
    assert(oo_list_ambient_bytes == bytes_with_ms);
  }

  oo_ll_S_release(ms);
  assert(oo_list_ambient_bytes == bytes_before);
}

int main(void) {
  test_flist_inplace_10k_physics();
  test_flist_cow_and_precision_physics();
  test_2d_matrix_slice_exact_arc_physics();
  test_2d_string_matrix_slice_physics();
  printf("PASS: deep substrate physics M1 iteration 2 verified (10k ops, bit-exact ARC, 0 leaks)\n");
  return 0;
}
