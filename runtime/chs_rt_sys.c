#include "chs_rt.h"
#include <errno.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>

/* ZT path A: process-policy getenv — fail-closed for non OODA_/OODAC_/OO_ keys.
 * Product env_get still requires EnvCap via oo_env_get. */
const char *oo_process_policy_getenv(const char *key) {
  if (!key || !key[0]) return NULL;
  if (strncmp(key, "OODA_", 5) != 0 && strncmp(key, "OODAC_", 6) != 0 && strncmp(key, "OO_", 3) != 0) {
    return NULL;
  }
  return getenv(key);
}

/* Child of sys_exec / sys_spawn: keep OODA_/OO_ keys only, then PATH=/usr/bin:/bin. */
void oo_child_filter_env(void) {
  extern char **environ;
  char **src;
  char **newenv = NULL;
  size_t n = 0, env_cap = 0;
  if (environ) {
    for (src = environ; *src; src++) {
      const char *eq = strchr(*src, '=');
      size_t klen;
      if (!eq) continue;
      klen = (size_t)(eq - *src);
      if (klen == 0) continue;
      if (!((klen >= 5 && strncmp(*src, "OODA_", 5) == 0) ||
            (klen >= 6 && strncmp(*src, "OODAC_", 6) == 0) ||
            (klen >= 3 && strncmp(*src, "OO_", 3) == 0)))
        continue;
      if (n + 1 >= env_cap) {
        env_cap = env_cap ? env_cap * 2 : 16;
        newenv = (char **)realloc(newenv, env_cap * sizeof(char *));
        if (!newenv) _exit(127);
      }
      newenv[n++] = *src;
    }
  }
#if defined(__GLIBC__) || defined(__APPLE__)
  clearenv();
#else
  if (environ) {
    environ[0] = NULL;
  }
#endif
  if (newenv) {
    newenv[n] = NULL;
    environ = newenv;
  }
  setenv("PATH", "/usr/bin:/bin", 1);
}

int oo_policy_write_on(void) {
  const char *v = oo_process_policy_getenv("OODA_POLICY_WRITE");
  return v && v[0] == '1' && v[1] == '\0';
}

int oo_is_policy_path(const char *p) {
  const char *b;
  size_t n;
  if (!p || !p[0]) return 0;
  if (strstr(p, "/.config/ooda/")) return 1;
  b = strrchr(p, '/');
  b = b ? b + 1 : p;
  if (strcmp(b, "SOUL.md") == 0 || strcmp(b, "soul.md") == 0) return 1;
  if (strcmp(b, ".bashrc") == 0 || strcmp(b, "ooda.lock") == 0) return 1;
  n = strlen(b);
  if (n >= 10 && strcmp(b + (n - 10), ".agent.pin") == 0) return 1;
  return 0;
}

/* R2/R3: fork + execvp with full argv (no system(3) shell). Captures the
 * child's stdout via a pipe so callers can branch on the captured report
 * (this is the only way to make a redteam gate that actually observes the
 * child process's verdict). Captured output is bounded to OO_SYS_EXEC_MAX_OUT
 * bytes; a child that floods the pipe will see EPIPE on its next write.
 * The returned OoStr is ref-counted so callers can oo_str_release it. */
#define OO_SYS_EXEC_MAX_OUT (32u << 20)

OoResS oo_sys_exec(long long cap, int argc, OoStr *argv) {
  OoResS r;
  char **av;
  int i, st;
  long long k;
  pid_t pid;
  int pipefd[2];
  char *out_buf = NULL;
  size_t out_n = 0;
  oo_cap_require_process(cap, "sys_exec");
  r.ok = 0;
  r.val = oo_str_lit("sys_exec failed");
  if (argc < 1 || !argv || !argv[0].data) return r;
  if (pipe(pipefd) < 0) return r;
  av = (char **)calloc((size_t)argc + 1, sizeof(char *));
  if (!av) { close(pipefd[0]); close(pipefd[1]); return r; }
  for (i = 0; i < argc; i++) {
    /* Fail-closed like to_cpath: empty / len<=0 / NUL inside .len → no exec. */
    if (!argv[i].data || argv[i].len <= 0) {
      free(av);
      close(pipefd[0]); close(pipefd[1]);
      return r;
    }
    for (k = 0; k < argv[i].len; k++) {
      if (argv[i].data[k] == '\0') {
        free(av);
        close(pipefd[0]); close(pipefd[1]);
        return r;
      }
    }
    char *ac = (char *)malloc((size_t)argv[i].len + 1);
    if (!ac) { for (int j = 0; j < i; j++) free(av[j]); free(av); close(pipefd[0]); close(pipefd[1]); return r; }
    memcpy(ac, argv[i].data, (size_t)argv[i].len);
    ac[argv[i].len] = '\0';
    av[i] = ac;
  }
  av[argc] = NULL;
  pid = fork();
  if (pid < 0) {
    for (i = 0; i < argc; i++) free(av[i]);
    free(av);
    close(pipefd[0]); close(pipefd[1]);
    return r;
  }
  if (pid == 0) {
    close(pipefd[0]);
    if (dup2(pipefd[1], STDOUT_FILENO) < 0) _exit(126);
    if (dup2(pipefd[1], STDERR_FILENO) < 0) _exit(126);
    close(pipefd[1]);
    oo_child_filter_env();
    execvp(av[0], av);
    _exit(127);
  }
  close(pipefd[1]);
  {
    size_t capn = 1u << 20;
    char *grow = (char *)malloc(capn);
    if (!grow) {
      kill(pid, SIGKILL);
      close(pipefd[0]);
      for (i = 0; i < argc; i++) free(av[i]);
      free(av);
      waitpid(pid, &st, 0);
      return r;
    }
    for (;;) {
      if (out_n == capn) {
        size_t ncap;
        char *nb;
        if (capn >= OO_SYS_EXEC_MAX_OUT) {
          kill(pid, SIGKILL);
          break;
        }
        ncap = capn * 2;
        if (ncap > OO_SYS_EXEC_MAX_OUT) ncap = OO_SYS_EXEC_MAX_OUT;
        nb = (char *)realloc(grow, ncap);
        if (!nb) {
          kill(pid, SIGKILL);
          break;
        }
        grow = nb;
        capn = ncap;
      }
      {
        ssize_t got = read(pipefd[0], grow + out_n, capn - out_n);
        if (got <= 0) break;
        out_n += (size_t)got;
      }
    }
    close(pipefd[0]);
    for (i = 0; i < argc; i++) free(av[i]);
    free(av);
    if (waitpid(pid, &st, 0) < 0) {
      free(grow);
      return r;
    }
    out_buf = oo_str_alloc_payload(out_n > 0 ? out_n : 1);
    if (!out_buf) {
      free(grow);
      return r;
    }
    if (out_n > 0) memcpy(out_buf, grow, out_n);
    free(grow);
    if (WIFEXITED(st) && WEXITSTATUS(st) == 0) r.ok = 1;
    r.val.data = out_buf;
    r.val.len = (long long)out_n;
    return r;
  }
}

/* Inherit stdio, wait, return the exit code. Distinct from oo_sys_exec (captures stdout, Ok only on 0). */
OoResI oo_sys_exec_wait(long long cap, OoStr prog, OoSList argv) {
  OoResI r;
  char **av;
  int i, st, argc;
  long long k;
  pid_t pid;
  oo_cap_require_process(cap, "sys_exec_wait");
  r.ok = 0;
  r.val = 0;
  r.err = oo_str_lit("sys_exec_wait failed");
  if (!prog.data || prog.len <= 0) return r;
  for (k = 0; k < prog.len; k++) {
    if (prog.data[k] == '\0') return r;
  }
  if (argv.len < 0) return r;
  if (argv.len > 0 && !argv.data) return r;
  argc = 1 + (int)argv.len;
  av = (char **)calloc((size_t)argc + 1, sizeof(char *));
  if (!av) return r;
  av[0] = (char *)malloc((size_t)prog.len + 1);
  if (!av[0]) { free(av); return r; }
  memcpy(av[0], prog.data, (size_t)prog.len);
  av[0][prog.len] = '\0';
  for (i = 0; i < (int)argv.len; i++) {
    if (!argv.data[i].data || argv.data[i].len <= 0) {
      for (int j = 0; j <= i; j++) free(av[j]);
      free(av);
      return r;
    }
    for (k = 0; k < argv.data[i].len; k++) {
      if (argv.data[i].data[k] == '\0') {
        for (int j = 0; j <= i; j++) free(av[j]);
        free(av);
        return r;
      }
    }
    av[i + 1] = (char *)malloc((size_t)argv.data[i].len + 1);
    if (!av[i + 1]) {
      for (int j = 0; j <= i; j++) free(av[j]);
      free(av);
      return r;
    }
    memcpy(av[i + 1], argv.data[i].data, (size_t)argv.data[i].len);
    av[i + 1][argv.data[i].len] = '\0';
  }
  av[argc] = NULL;
  pid = fork();
  if (pid < 0) {
    for (i = 0; i < argc; i++) free(av[i]);
    free(av);
    return r;
  }
  if (pid == 0) {
    oo_child_filter_env();
    execvp(av[0], av);
    _exit(127);
  }
  for (i = 0; i < argc; i++) free(av[i]);
  free(av);
  if (waitpid(pid, &st, 0) < 0) return r;
  r.ok = 1;
  r.err = oo_str_lit("");
  if (WIFEXITED(st)) r.val = (long long)WEXITSTATUS(st);
  else if (WIFSIGNALED(st)) r.val = 128LL + (long long)WTERMSIG(st);
  else r.val = 1;
  return r;
}

OoSList oo_sys_args(long long cap) {
  oo_cap_require_process(cap, "sys_args");
  OoSList l = oo_slist_new();
  FILE *f = fopen("/proc/self/cmdline", "rb");
  if (!f) return l;
  char buf[4096];
  size_t n = fread(buf, 1, sizeof(buf) - 1, f);
  fclose(f);
  if (n == 0) return l;
  size_t start = 0;
  size_t i;
  int first = 1;
  for (i = 0; i < n; i++) {
    if (buf[i] == '\0') {
      if (!first) {
        OoStr arg = oo_str_lit(buf + start);
        OoSList next = oo_slist_push(l, arg);
        oo_slist_release(l);
        l = next;
        oo_str_release(arg);
      }
      first = 0;
      start = i + 1;
    }
  }
  return l;
}

#include <sys/stat.h>

/* Read all stdin (stdio LSP / one-shot). Pipes have no seek. */
OoStr oo_read_stdin(void) {
  char *buf;
  size_t cap = 4096;
  size_t n = 0;
  buf = (char *)malloc(cap);
  if (!buf) return oo_str_lit("");
  for (;;) {
    size_t got;
    if (n + 1024 >= cap) {
      char *nb;
      cap *= 2;
      if (cap > (1u << 20)) {
        free(buf);
        return oo_str_lit("");
      }
      nb = (char *)realloc(buf, cap);
      if (!nb) {
        free(buf);
        return oo_str_lit("");
      }
      buf = nb;
    }
    got = fread(buf + n, 1, 1024, stdin);
    n += got;
    if (got < 1024) break;
  }
  {
    OoStr r;
    r.data = buf;
    r.len = (long long)n;
    return r;
  }
}

/* Fast cache key: size:mtime:nsec. Avoids hashing whole compiler sources. */
OoStr oo_file_stamp(OoStr path) {
  char cpath[PATH_MAX];
  struct stat st;
  char buf[96];
  if (!path.data || path.len <= 0 || path.len >= PATH_MAX) return oo_str_lit("0:0:0");
  memcpy(cpath, path.data, (size_t)path.len);
  cpath[path.len] = 0;
  if (stat(cpath, &st) != 0) return oo_str_lit("0:0:0");
#if defined(__APPLE__)
  snprintf(buf, sizeof buf, "%lld:%lld:%lld", (long long)st.st_size, (long long)st.st_mtimespec.tv_sec, (long long)st.st_mtimespec.tv_nsec);
#elif defined(_WIN32)
  snprintf(buf, sizeof buf, "%lld:%lld:0", (long long)st.st_size, (long long)st.st_mtime);
#else
  snprintf(buf, sizeof buf, "%lld:%lld:%lld", (long long)st.st_size, (long long)st.st_mtim.tv_sec, (long long)st.st_mtim.tv_nsec);
#endif
  return oo_str_lit(buf);
}

void oo_process_exit(long long c) {
  exit((int)c);
}

/* Non-blocking stdin read for the LSP stdio loop.
   Returns Result<String, String>:
     ok=1, val=<chunk> when data is available.
     ok=0, val="" when the poll timed out, EOF was reached, or read() failed.
   The caller loops with a short timeout (e.g. 100ms) and dispatches
   complete Content-Length or JSON-object frames as they accumulate. */
#include <poll.h>
OoResS oo_read_stdin_chunk(long long timeout_ms) {
  struct pollfd pfd;
  pfd.fd = 0;
  pfd.events = POLLIN;
  int rc = poll(&pfd, 1, (int)timeout_ms);
  if (rc <= 0) {
    OoStr empty = oo_str_lit("");
    OoResS r = { .ok = 0, .val = empty };
    return r;
  }
  if (!(pfd.revents & POLLIN)) {
    OoStr empty = oo_str_lit("");
    OoResS r = { .ok = 0, .val = empty };
    return r;
  }
  char *buf = (char *)malloc(4096);
  if (!buf) {
    OoStr empty = oo_str_lit("");
    OoResS r = { .ok = 0, .val = empty };
    return r;
  }
  ssize_t got = read(0, buf, 4096);
  if (got <= 0) {
    free(buf);
    OoStr empty = oo_str_lit("");
    OoResS r = { .ok = 0, .val = empty };
    return r;
  }
  OoStr chunk;
  chunk.data = buf;
  chunk.len = (long long)got;
  OoResS r = { .ok = 1, .val = chunk };
  return r;
}
