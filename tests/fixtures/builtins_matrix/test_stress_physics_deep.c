/* Deep Substrate Physics Stress Test: In-Place Zero-Realloc, COW Alternation, and 2D Refcounts */
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include "oodar.h"

extern long long oo_list_ambient_bytes;

static OoIList sim_assign_push(OoIList l, long long v) {
  OoIList old = l;
  OoIList ret = oo_ilist_push(l, v);
  oo_ilist_release(old);
  return ret;
}

static OoIList sim_assign_set(OoIList l, long long i, long long v) {
  OoIList old = l;
  OoIList ret = oo_ilist_set(l, i, v);
  oo_ilist_release(old);
  return ret;
}

static OoSList sim_slist_push(OoSList l, OoStr v) {
  OoSList old = l;
  OoSList ret = oo_slist_push(l, v);
  oo_slist_release(old);
  return ret;
}

static OoSList sim_slist_set(OoSList l, long long i, OoStr v) {
  OoSList old = l;
  OoSList ret = oo_slist_set(l, i, v);
  oo_slist_release(old);
  return ret;
}

static void test_inplace_10k_zero_realloc(void) {
  OoIList l = oo_ilist_new();
  for (long long i = 0; i < 16; i++) {
    l = sim_assign_push(l, i * 10);
  }
  void *orig_data = l.data;
  OoListHeader *h0 = ((OoListHeader *)l.data) - 1;
  assert(h0->ref_count == 1);
  long long bytes_before = oo_list_ambient_bytes;

  /* 10,000 in-place mutations asserting bit-identical data pointer and rc=1 */
  for (long long k = 0; k < 10000; k++) {
    long long idx = k % 16;
    long long expected = k * 17 + 5;
    l = sim_assign_set(l, idx, expected);
    assert(l.data == orig_data); /* ZERO REALLOCATIONS */
    assert(l.data[idx] == expected);
    OoListHeader *hk = ((OoListHeader *)l.data) - 1;
    assert(hk->ref_count == 1); /* REFCOUNT STAYS STRICTLY 1 */
    assert(oo_list_ambient_bytes == bytes_before); /* CONSTANT MEMORY FOOTPRINT */
  }
  oo_ilist_release(l);
}

static void test_cow_alternating_1k(void) {
  OoIList a = oo_ilist_new();
  for (long long i = 0; i < 8; i++) a = sim_assign_push(a, i * 10);
  
  for (long long k = 0; k < 1000; k++) {
    /* 1. Share: refcount becomes 2 */
    oo_ilist_retain(a);
    OoListHeader *ha = ((OoListHeader *)a.data) - 1;
    assert(ha->ref_count == 2);

    /* 2. Mutate clone: COW triggers */
    OoIList b = a;
    long long b_val = k * 100 + 1;
    OoIList b_mod = oo_ilist_set(b, 0, b_val);
    assert(b_mod.data != a.data); /* DISJOINT BUFFERS */
    assert(a.data[0] != b_val);   /* ORIGINAL UNMODIFIED */
    assert(b_mod.data[0] == b_val);

    /* Release old clone reference */
    oo_ilist_release(b);
    assert(ha->ref_count == 1);   /* ORIGINAL RESTORED TO RC=1 */

    OoListHeader *hb = ((OoListHeader *)b_mod.data) - 1;
    assert(hb->ref_count == 1);   /* CLONE IS SINGLE-OWNER RC=1 */

    /* 3. Mutate original in-place since rc==1 */
    void *a_ptr_before = a.data;
    long long a_val = k * 100 + 2;
    a = sim_assign_set(a, 0, a_val);
    assert(a.data == a_ptr_before); /* IN-PLACE WRITTEN */
    assert(a.data[0] == a_val);
    assert(b_mod.data[0] == b_val); /* CLONE STILL UNMODIFIED */

    oo_ilist_release(b_mod);
  }
  oo_ilist_release(a);
}

static void test_nested_2d_physics(void) {
  OoLL_I m = oo_ll_I_new();
  for (int r = 0; r < 3; r++) {
    OoIList row = oo_ilist_new();
    for (int c = 0; c < 3; c++) row = sim_assign_push(row, r * 10 + c);
    OoLL_I old_m = m;
    m = oo_ll_I_push(m, row);
    oo_ll_I_release(old_m);
    oo_ilist_release(row);
  }
  void *orig_m_data = m.data;
  OoListHeader *hm = ((OoListHeader *)m.data) - 1;
  assert(hm->ref_count == 1);

  /* Single owner: row replacement in-place */
  OoIList new_row = oo_ilist_new();
  new_row = sim_assign_push(new_row, 777);
  OoLL_I old_m = m;
  m = oo_ll_I_set(m, 0, new_row);
  oo_ll_I_release(old_m);
  oo_ilist_release(new_row);
  assert(m.data == orig_m_data); /* Zero outer realloc */

  /* Shared owner: COW on outer list */
  oo_ll_I_retain(m);
  assert(hm->ref_count == 2);
  OoIList rep_row = oo_ilist_new();
  rep_row = sim_assign_push(rep_row, 999);
  OoLL_I branched = oo_ll_I_set(m, 1, rep_row);
  assert(branched.data != m.data); /* Disjoint outer buffers */
  oo_ll_I_release(m);
  oo_ilist_release(rep_row);
  oo_ll_I_release(branched);
  oo_ll_I_release(m);
}

static void test_extreme_slices_physics(void) {
  OoIList l = oo_ilist_new();
  for (long long i = 0; i < 10; i++) l = sim_assign_push(l, i);

  /* Negative bounds */
  OoIList s1 = oo_ilist_slice(l, -100, -50);
  assert(s1.len == 0);
  oo_ilist_release(s1);

  /* Inverted bounds */
  OoIList s2 = oo_ilist_slice(l, 8, 2);
  assert(s2.len == 0);
  oo_ilist_release(s2);

  /* Huge bounds */
  OoIList s3 = oo_ilist_slice(l, -50, 1000000);
  assert(s3.len == 10);
  for (long long i = 0; i < 10; i++) assert(s3.data[i] == i);
  oo_ilist_release(s3);

  oo_ilist_release(l);
}

int main(void) {
  test_inplace_10k_zero_realloc();
  test_cow_alternating_1k();
  test_nested_2d_physics();
  test_extreme_slices_physics();
  printf("PASS: deep substrate physics stress test verified\n");
  return 0;
}
