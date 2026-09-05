/* Apply Landlock when the process jail env is set. Fail closed. */
#include "chs_rt.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>

static OoStr jail_str(const char *s) {
  OoStr o;
  o.data = (char *)s;
  o.len = s ? (long long)strlen(s) : 0;
  return o;
}

__attribute__((constructor)) static void oo_jail_landlock_ctor(void) {
  const char *rd = getenv("OODA_FS_READDIR");
  const char *wd = getenv("OODA_FS_WRITEDIR");
  OoStr reads, writes;
  OoResS r;
  long long sys;
  if (!rd || !rd[0] || !wd || !wd[0]) return;
  if (!oo_landlock_is_available()) {
    fprintf(stderr, "ERR\tlandlock\trequired when OODA_FS_READDIR/WRITEDIR set\n");
    _exit(1);
  }
  reads = jail_str("/usr:/bin:/lib:/lib64");
  if (rd[0] == '/') {
    static char rbuf[PATH_MAX * 2];
    size_t n = 0;
    const char *pre = "/usr:/bin:/lib:/lib64:";
    while (pre[n] && n + 1 < sizeof rbuf) { rbuf[n] = pre[n]; n++; }
    while (*rd && n + 1 < sizeof rbuf) rbuf[n++] = *rd++;
    rbuf[n] = 0;
    reads = jail_str(rbuf);
  }
  {
    static char wbuf[PATH_MAX * 2];
    size_t n = 0;
    const char *w = wd;
    const char *suf = ":/tmp";
    while (w && *w && n + 1 < sizeof wbuf) wbuf[n++] = *w++;
    while (*suf && n + 1 < sizeof wbuf) wbuf[n++] = *suf++;
    wbuf[n] = 0;
    writes = jail_str(wbuf);
  }
  sys = oo_cap_grant_sys();
  r = oo_landlock_restrict(sys, reads, writes);
  if (!r.ok) {
    fprintf(stderr, "ERR\tlandlock\tjail apply failed\n");
    _exit(1);
  }
}
