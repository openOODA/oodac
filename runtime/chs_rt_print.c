#include "chs_rt.h"
#include <unistd.h>

/* OPEN-8: in-process oodac --json-errors. Armed by a cwd flag file so the
 * first rebuild can use this runtime without a new .oo builtin. */
static int oo_je_checked = 0;
static int oo_je_on = 0;
static int oo_je_n = 0;
static int oo_je_atexit = 0;
static char oo_je_path[512];

static int oo_je_armed(void) {
  if (!oo_je_checked) {
    const char *je;
    oo_je_checked = 1;
    oo_je_path[0] = 0;

    /* 1. Check environment variable OODA_JSON_ERRORS */
    je = oo_process_policy_getenv("OODA_JSON_ERRORS");
    if (!je) je = getenv("OODA_JSON_ERRORS");
    if (je && je[0] && strcmp(je, "0") != 0) {
      oo_je_on = 1;
      if (strcmp(je, "1") != 0 && strcmp(je, "true") != 0) {
        strncpy(oo_je_path, je, sizeof(oo_je_path) - 1);
        oo_je_path[sizeof(oo_je_path) - 1] = 0;
      } else {
        const char *jp = oo_process_policy_getenv("OODA_JSON_PATH");
        if (!jp) jp = getenv("OODA_JSON_PATH");
        if (jp && jp[0]) {
          strncpy(oo_je_path, jp, sizeof(oo_je_path) - 1);
          oo_je_path[sizeof(oo_je_path) - 1] = 0;
        }
      }
    }

    /* 2. Direct binary invocation fallback: inspect /proc/self/cmdline */
    if (!oo_je_on) {
      FILE *fcmd = fopen("/proc/self/cmdline", "rb");
      if (fcmd) {
        char buf[2048];
        size_t n = fread(buf, 1, sizeof(buf) - 1, fcmd);
        fclose(fcmd);
        if (n > 0) {
          size_t idx = 0;
          int found_je = 0;
          char last_path[512] = {0};
          while (idx < n) {
            const char *arg = buf + idx;
            size_t alen = strlen(arg);
            if (strcmp(arg, "--json-errors") == 0 || strcmp(arg, "-json") == 0) {
              found_je = 1;
            } else if (alen > 3 && strcmp(arg + alen - 3, ".oo") == 0) {
              strncpy(last_path, arg, sizeof(last_path) - 1);
            }
            idx += alen + 1;
          }
          if (found_je) {
            oo_je_on = 1;
            if (last_path[0]) {
              strncpy(oo_je_path, last_path, sizeof(oo_je_path) - 1);
              oo_je_path[sizeof(oo_je_path) - 1] = 0;
            }
          }
        }
      }
    }
  }
  return oo_je_on;
}

static void oo_je_esc(FILE *f, const char *p, long long n) {
  for (long long i = 0; i < n; i++) {
    char c = p[i];
    if (c == '\\' || c == '"') {
      fputc('\\', f);
      fputc(c, f);
    } else if (c == '\n') {
      fputs("\\n", f);
    } else if (c == '\t') {
      fputs("\\t", f);
    } else {
      fputc(c, f);
    }
  }
}

static const char *oo_je_code(const char *p, long long n) {
  for (long long i = 0; i + 10 < n; i++) {
    if (memcmp(p + i, "capability", 10) == 0) return "E_CAP";
  }
  for (long long i = 0; i + 4 < n; i++) {
    if (memcmp(p + i, "type", 4) == 0 && (i == 0 || p[i - 1] == '\t')) return "E_TC";
  }
  for (long long i = 0; i + 5 < n; i++) {
    if (memcmp(p + i, "parse", 5) == 0) return "E_PARSE";
  }
  for (long long i = 0; i + 6 < n; i++) {
    if (memcmp(p + i, "secret", 6) == 0) return "E_SECRET";
  }
  return "E_OTHER";
}

static void oo_je_flush(void) {
  if (!oo_je_on) return;
  if (oo_je_n == 0) {
    fputs("[]\n", stdout);
  } else {
    fputs("]\n", stdout);
  }
}

static void oo_je_loc(const char *p, long long n, long long *line, long long *col) {
  long long l = 1, c = 1;
  for (long long i = 0; i + 5 < n; i++) {
    if (p[i] == ':' && isdigit((unsigned char)p[i + 1])) {
      long long v = 0;
      long long j = i + 1;
      while (j < n && isdigit((unsigned char)p[j])) {
        v = v * 10 + (p[j] - '0');
        j++;
      }
      if (v > 0) {
        l = v;
        if (j < n && p[j] == ':') {
          long long c2 = 0;
          j++;
          while (j < n && isdigit((unsigned char)p[j])) {
            c2 = c2 * 10 + (p[j] - '0');
            j++;
          }
          if (c2 > 0) c = c2;
        }
        break;
      }
    }
  }
  *line = l;
  *col = c;
}

static void oo_je_emit(OoStr s) {
  const char *code;
  long long line = 0, col = 0;
  if (oo_je_n == 0) fputc('[', stdout);
  else fputc(',', stdout);
  code = oo_je_code(s.data, s.len);
  oo_je_loc(s.data, s.len, &line, &col);
  fputs("{\"code\":\"", stdout);
  fputs(code, stdout);
  fprintf(stdout, "\",\"line\":%lld,\"col\":%lld,\"msg\":\"", line, col);
  oo_je_esc(stdout, s.data, s.len);
  fputs("\",\"path\":\"", stdout);
  oo_je_esc(stdout, oo_je_path, (long long)strlen(oo_je_path));
  fputs("\",\"fix_hint\":\"See openOODA/SHIPPED.oot and ROADMAP.oot.\"", stdout);
  if (strcmp(code, "E_CAP") == 0) {
    fputs(",\"kind\":\"CapabilitySecurityViolation\",\"suggested_fix\":\"Add a matching &Cap parameter\"", stdout);
  }
  fputc('}', stdout);
  oo_je_n++;
}

void oo_print_str(OoStr s) {
  int armed = oo_je_armed();
  if (s.data && s.len >= 4 && armed && memcmp(s.data, "ERR\t", 4) == 0) {
    if (!oo_je_atexit) {
      atexit(oo_je_flush);
      oo_je_atexit = 1;
    }
    oo_je_emit(s);
    return;
  }
  if (s.data && s.len >= 2 && armed && s.data[0] == 'O' && s.data[1] == 'K') {
    if (!oo_je_atexit) {
      atexit(oo_je_flush);
      oo_je_atexit = 1;
    }
    return;
  }
  fwrite(s.data, 1, (size_t)s.len, stdout);
}

void oo_eprint_str(OoStr s) { fwrite(s.data, 1, (size_t)s.len, stderr); }
void oo_print_int(long long n) { printf("%lld", n); }
void oo_print_bool(int b) { fputs(b ? "true" : "false", stdout); }
void oo_println(void) {
  if (oo_je_armed()) {
    if (!oo_je_atexit) {
      atexit(oo_je_flush);
      oo_je_atexit = 1;
    }
    return;
  }
  fputc('\n', stdout);
}
void oo_eprintln(void) { fputc('\n', stderr); }
