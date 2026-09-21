/* Substrate test asserting bit-exact refcount, zero reallocations, and quota invariance. */
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include "oodar.h"

extern long long oo_list_ambient_bytes;

static OoIList simulate_assign_push(OoIList l, long long v) {
  OoIList old = l;
  OoIList ret = oo_ilist_push(l, v);
  oo_ilist_release(old);
  return ret;
}

static OoIList simulate_assign_set(OoIList l, long long i, long long v) {
  OoIList old = l;
  OoIList ret = oo_ilist_set(l, i, v);
  oo_ilist_release(old);
  return ret;
}

int main(void) {
  /* 1. In-place single-owner mutation: refcount stays 1, zero reallocations */
  OoIList l = oo_ilist_new();
  l = simulate_assign_push(l, 42);
  void *orig_data = l.data;
  OoListHeader *h0 = ((OoListHeader *)l.data) - 1;
  assert(h0->ref_count == 1);
  long long bytes_before = oo_list_ambient_bytes;

  l = simulate_assign_set(l, 0, 99);
  /* Assert zero reallocations: data pointer must be bit-identical */
  assert(l.data == orig_data);
  /* Assert value updated */
  assert(l.data[0] == 99);
  /* Assert refcount strictly stays 1 */
  OoListHeader *h1 = ((OoListHeader *)l.data) - 1;
  assert(h1->ref_count == 1);
  /* Assert ambient bytes unchanged */
  assert(oo_list_ambient_bytes == bytes_before);

  /* 2. COW path: refcount > 1 */
  oo_ilist_retain(l); /* simulate let b = a; refcount becomes 2 */
  OoListHeader *h_shared = ((OoListHeader *)l.data) - 1;
  assert(h_shared->ref_count == 2);

  /* let c = list_set(b, 0, 123) (new variable binding) */
  OoIList cloned = oo_ilist_set(l, 0, 123);
  /* Assert reallocation: cloned buffer must be distinct */
  assert(cloned.data != l.data);
  /* Assert original unmodified */
  assert(l.data[0] == 99);
  /* Assert cloned updated */
  assert(cloned.data[0] == 123);
  /* Assert shared buffer retains refcount 2 */
  assert(h_shared->ref_count == 2);
  /* Assert cloned has fresh refcount 1 */
  OoListHeader *h_cloned = ((OoListHeader *)cloned.data) - 1;
  assert(h_cloned->ref_count == 1);

  oo_ilist_release(l);
  oo_ilist_release(l);
  oo_ilist_release(cloned);
  printf("PASS: list memory physics verified\n");
  return 0;
}
