#!/usr/bin/env bash
# # Adversarial & Concurrency Stress Test Suite for Milestone 2
#
# Logline: Stress-test compiled polyrepo binaries:
#   cli, ooda, opm, lsp, mcp, hello.
#
# Setup: Requires bin/ binaries. Tests hostile flags, payloads, and concurrency.
#
# Beats:
#   1. Binary presence, ELF format, and dynamic library linkage.
#   2. Hostile CLI inputs: empty, unknown flags, and subcommands.
#   3. Adversarial payloads: large buffers, format strings, path traversals.
#   4. Subcommand-specific fail-closed error paths.
#   5. High-concurrency burst and thread pool execution.
#   6. Resource leak (FDs) and defunct process audit.

set -euo pipefail

ROOT="/home/jeryd/Projects/openOODA"
BIN_DIR="$ROOT/bin"
PASS=0
FAIL=0

log_pass() {
  echo "  [PASS] $1"
  PASS=$((PASS + 1))
}

log_fail() {
  echo "  [FAIL] $1"
  FAIL=$((FAIL + 1))
}

assert_no_crash() {
  local desc="$1"
  shift
  local code=0
  "$@" >/dev/null 2>&1 || code=$?
  if [ "$code" -eq 134 ] || [ "$code" -eq 135 ] || [ "$code" -eq 139 ]; then
    log_fail "$desc (crashed with signal/exit $code)"
  else
    log_pass "$desc (exit $code, no crash)"
  fi
}

echo "=== M2 Adversarial & Concurrency Stress Suite ==="

# Beat 1: Binary presence and ELF integrity
echo "--- Beat 1: Binary presence and ELF architecture ---"
for b in cli ooda opm lsp mcp hello; do
  target="$BIN_DIR/$b"
  if [ -x "$target" ] && file "$target" | grep -q "ELF 64-bit"; then
    log_pass "ELF binary valid: bin/$b"
  else
    log_fail "Missing or non-ELF binary: bin/$b"
  fi
  if ! ldd "$target" | grep -q "not found"; then
    log_pass "Dynamic libraries resolved: bin/$b"
  else
    log_fail "Unresolved dynamic libraries: bin/$b"
  fi
done

# Beat 2: Adversarial CLI inputs
echo "--- Beat 2: Hostile flags and empty/unknown arguments ---"
assert_no_crash "cli empty arg" "$BIN_DIR/cli" ""
assert_no_crash "cli unknown subcommand" "$BIN_DIR/cli" "nonexistent_subcmd"
assert_no_crash "cli invalid flag" "$BIN_DIR/cli" "--invalid-flag"

assert_no_crash "ooda empty arg" "$BIN_DIR/ooda" ""
assert_no_crash "ooda unknown subcommand" "$BIN_DIR/ooda" "nonexistent_subcmd"
assert_no_crash "ooda invalid flag" "$BIN_DIR/ooda" "--invalid-flag"

assert_no_crash "opm empty arg" "$BIN_DIR/opm" ""
assert_no_crash "opm unknown subcommand" "$BIN_DIR/opm" "nonexistent_subcmd"
assert_no_crash "opm invalid flag" "$BIN_DIR/opm" "--invalid-flag"

assert_no_crash "lsp unknown file" "$BIN_DIR/lsp" "/nonexistent/path/file.json"
assert_no_crash "lsp bad stdlib root" "$BIN_DIR/lsp" \
  --stdlib-root "../../../etc"
assert_no_crash "lsp bad oodar root" "$BIN_DIR/lsp" --oodar-root "/proc"

assert_no_crash "mcp unknown subcommand" "$BIN_DIR/mcp" "nonexistent_subcmd"
assert_no_crash "mcp unknown flag" "$BIN_DIR/mcp" "--invalid-flag"
assert_no_crash "mcp mutually exclusive" "$BIN_DIR/mcp" \
  --stdio --file "/tmp/foo"

assert_no_crash "hello excess arguments" "$BIN_DIR/hello" "foo" "bar" "baz"

# Beat 3: Adversarial payloads
echo "--- Beat 3: Large buffers, format strings, traversals ---"
payload_large=$(python3 -c 'print("A" * 32768)')
payload_fmt="%s%s%n%x%p%#x"
payload_trav="../../../../etc/shadow"
payload_chars='!@#$%^&*()_+~`|}{[]\:;?><,./'

for b in cli ooda opm lsp mcp hello; do
  assert_no_crash "$b: 32KB payload" "$BIN_DIR/$b" "$payload_large"
  assert_no_crash "$b: format string" "$BIN_DIR/$b" "$payload_fmt"
  assert_no_crash "$b: path traversal" "$BIN_DIR/$b" "$payload_trav"
  assert_no_crash "$b: special chars" "$BIN_DIR/$b" "$payload_chars"
done

# Beat 4: Subcommand-specific fail-closed behavior
echo "--- Beat 4: Subcommand-specific fail-closed verification ---"
# cli build missing file -> exit 2
code=0; "$BIN_DIR/cli" build >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] && log_pass "cli build missing file exit 2" \
  || log_fail "cli build missing file expected exit 2, got $code"

# cli build unreadable file -> exit 2
code=0; "$BIN_DIR/cli" build "/nonexistent.oo" >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] && log_pass "cli build unreadable file exit 2" \
  || log_fail "cli build unreadable file expected exit 2, got $code"

# ooda no-arg without OODACODEX fails closed -> exit 1
code=0; "$BIN_DIR/ooda" >/dev/null 2>&1 || code=$?
[ "$code" -eq 1 ] && log_pass "ooda bare invocation exit 1" \
  || log_fail "ooda bare invocation expected exit 1, got $code"

# opm add missing arg -> exit 2
code=0; "$BIN_DIR/opm" add >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] && log_pass "opm add missing arg exit 2" \
  || log_fail "opm add missing arg expected exit 2, got $code"

# lsp missing request file -> exit 2
code=0; "$BIN_DIR/lsp" "/nonexistent.json" >/dev/null 2>&1 || code=$?
[ "$code" -eq 2 ] && log_pass "lsp missing file exit 2" \
  || log_fail "lsp missing file expected exit 2, got $code"

# lsp stdio clean EOF -> exit 0
code=0; echo "" | "$BIN_DIR/lsp" --stdio >/dev/null 2>&1 || code=$?
[ "$code" -eq 0 ] && log_pass "lsp stdio EOF clean exit 0" \
  || log_fail "lsp stdio EOF expected exit 0, got $code"

# mcp missing file -> exit 1
code=0; "$BIN_DIR/mcp" --file "/nonexistent.json" >/dev/null 2>&1 || code=$?
[ "$code" -eq 1 ] && log_pass "mcp missing file exit 1" \
  || log_fail "mcp missing file expected exit 1, got $code"

# Beat 5: Concurrency stress
echo "--- Beat 5: Concurrency stress (burst and thread pool) ---"
python3 -c '
import subprocess, concurrent.futures, time, sys

binaries = [
  ["bin/cli", "--help"],
  ["bin/cli", "version"],
  ["bin/cli", "unknown_cmd"],
  ["bin/ooda", "--help"],
  ["bin/ooda", "version"],
  ["bin/ooda", "unknown_cmd"],
  ["bin/opm", "--help"],
  ["bin/opm", "add"],
  ["bin/lsp", "--help"],
  ["bin/lsp", "--version"],
  ["bin/mcp", "--help"],
  ["bin/mcp", "--bogus"],
  ["bin/hello"],
]

def task(idx):
  cmd = binaries[idx % len(binaries)]
  devnull = subprocess.DEVNULL
  p = subprocess.Popen(cmd, stdout=devnull, stderr=devnull)
  p.wait(timeout=5)
  return p.returncode

t0 = time.time()
with concurrent.futures.ThreadPoolExecutor(max_workers=50) as ex:
  results = list(ex.map(task, range(500)))

crashes = [r for r in results if r in (134, 135, 139) or r < 0]
elapsed = time.time() - t0
if crashes:
  print(f"FAILED: {len(crashes)} crashes in 500 concurrent runs")
  sys.exit(1)
print(f"  500 concurrent invocations completed in {elapsed:.2f}s (0 crashes)")
' && log_pass "500 concurrent invocations passed" \
  || log_fail "Concurrency stress failed"

# Beat 6: FD leak and zombie audit
echo "--- Beat 6: FD leaks and defunct processes ---"
python3 -c '
import subprocess, os, sys

def count_fds():
  return len(os.listdir("/proc/self/fd"))

before = count_fds()
bins = ["cli", "ooda", "opm", "lsp", "mcp", "hello"]
for _ in range(50):
  for b in bins:
    cmd = [f"bin/{b}", "--help"]
    p = subprocess.Popen(cmd, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL)
    p.wait()
after = count_fds()
if before != after:
  print(f"FD leak: {before} -> {after}")
  sys.exit(1)
' && log_pass "FD leak check passed (0 leaked FDs)" \
  || log_fail "FD leak detected"

zombie_count=$(ps -eo stat,pid,comm | grep -c -E '^[Zz]' || true)
if [ "$zombie_count" -eq 0 ]; then
  log_pass "Defunct process check passed (0 zombies)"
else
  log_fail "Defunct processes found: $zombie_count"
fi

echo "=== Suite Summary ==="
echo "PASS: $PASS | FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
