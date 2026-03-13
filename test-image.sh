#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-kali-recon:test}"
SHOTTED_IMAGE="${IMAGE}-with-shot"
BUILD_DEFAULT="${BUILD_DEFAULT:-1}"
BUILD_SCREENSHOT="${BUILD_SCREENSHOT:-0}"
SKIP_NETWORK_CHECK="${SKIP_NETWORK_CHECK:-0}"

PASS=0
FAIL=0

log() {
  printf '[test] %s\n' "$1"
}

if [ "${BUILD_DEFAULT}" = "1" ]; then
  log "Building image: ${IMAGE}"
  docker build -t "$IMAGE" .
fi

if [ "${BUILD_SCREENSHOT}" = "1" ]; then
  log "Building screenshot variant: ${SHOTTED_IMAGE}"
  docker build --build-arg ENABLE_SCREENSHOT_TOOL=1 -t "$SHOTTED_IMAGE" .
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  log "ERROR: image '$IMAGE' not found. Build first or set IMAGE=<tag>."
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

mkdir -p "$tmpdir"/{input,output,config,tmp}
printf 'RECON_TEST_MARKER=ok\n' >"$tmpdir/config/test.env"
printf 'RECON_SHELL_MARKER=loaded\n' >"$tmpdir/config/shell.env"

cat >"$tmpdir/recon-check.sh" <<'CHECK_EOF'
#!/usr/bin/env bash
set -euo pipefail

fail=0
pass_one() { printf 'PASS %s\n' "$1"; }
fail_one() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }

if [ -n "${SKIP_NETWORK_CHECK:-0}" ] && [ "${SKIP_NETWORK_CHECK}" -ne 0 ]; then
  SKIP_NETWORK=1
else
  SKIP_NETWORK=0
fi

for d in /workspace /workspace/input /workspace/output /workspace/config /workspace/tmp; do
  if [ -d "$d" ]; then pass_one "dir:$d"; else fail_one "dir:$d"; fi
done

for c in curl wget git jq yq rg fd tree less dig nslookup host whois python3 pip3 subfinder amass httpx wpscan; do
  if command -v "$c" >/dev/null; then pass_one "cmd:$c"; else fail_one "cmd:$c"; fi
done

if [ "$(ps -p 1 -o comm= | tr -d ' ')" = "tini" ]; then pass_one "pid1-tini"; else fail_one "pid1-tini"; fi

if [ -x /usr/local/bin/docker-entrypoint ]; then pass_one "entrypoint-binary"; else fail_one "entrypoint-binary"; fi
if [ -x /usr/local/bin/recon-env ]; then pass_one "recon-env-binary"; else fail_one "recon-env-binary"; fi
if [ -f /var/lib/libpostal/transliteration ]; then pass_one "libpostal-hint"; else fail_one "libpostal-hint"; fi

if [ "$SKIP_NETWORK" -eq 0 ]; then
  if curl -I --max-time 8 --fail https://example.com >/dev/null; then pass_one "curl-example"; else fail_one "curl-example"; fi
  if wget -q -O /tmp/wget.out https://example.com; then pass_one "wget-example"; else fail_one "wget-example"; fi
else
  echo "SKIP: network-check"
fi

subfinder_out="$(subfinder -h 2>&1 || true)"
if printf '%s\n' "$subfinder_out" | grep -Eq '(Subfinder is|^Usage:)'; then pass_one "subfinder-help"; else fail_one "subfinder-help"; fi

amass_out="$(amass -h 2>&1 || true)"
if printf '%s\n' "$amass_out" | grep -qi '^Usage:'; then pass_one "amass-help"; else fail_one "amass-help"; fi

httpx_out="$(httpx -h 2>&1 || true)"
if printf '%s\n' "$httpx_out" | grep -qi '^[[:space:]]*Usage:'; then pass_one "httpx-help"; else fail_one "httpx-help"; fi

wpscan_out="$(wpscan --help 2>&1 || true)"
if printf '%s\n' "$wpscan_out" | grep -qi '^[[:space:]]*Usage'; then pass_one "wpscan-help"; else fail_one "wpscan-help"; fi

printf 'RECON_TEST_MARKER=ok\n' > /workspace/config/recon-test.env
if recon-env env | grep -q "RECON_TEST_MARKER=ok"; then pass_one "recon-env-load"; else fail_one "recon-env-load"; fi

echo "RESULT:$fail"
exit "$fail"
CHECK_EOF

chmod +x "$tmpdir/recon-check.sh"

run_full_test() {
  local image="$1"
  local skip_network="$2"
  local label="$3"
  local mount_workspace="$4"
  local host_user="$5"
  local -a run_cmd

  run_cmd=(docker run --rm -e SKIP_NETWORK_CHECK="$skip_network")
  if [ "$host_user" = "1" ]; then
    run_cmd+=(--user "$(id -u):$(id -g)" -e HOME=/tmp)
  fi
  if [ "$mount_workspace" = "1" ]; then
    run_cmd+=(-v "$tmpdir:/workspace")
  fi
  run_cmd+=(-v "$tmpdir/recon-check.sh:/tmp/recon-check.sh:ro" "$image" bash /tmp/recon-check.sh)

  log "Running checks: ${label} (${image})"
  set +e
  OUTPUT="$("${run_cmd[@]}" 2>&1)"
  local rc=$?
  set -e
  printf '%s\n' "$OUTPUT"
  if [ "$rc" -eq 0 ]; then
    PASS=$((PASS + 1))
    log "CHECKS: PASS (${label})"
  else
    FAIL=$((FAIL + 1))
    log "CHECKS: FAIL (${label})"
  fi
}

run_full_test "$IMAGE" "$SKIP_NETWORK_CHECK" "mounted workspace" 1 1
run_full_test "$IMAGE" "$SKIP_NETWORK_CHECK" "container default workspace" 0 0

log "Running one-off command test"
set +e
out="$(docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$tmpdir:/workspace" "$IMAGE" amass -h 2>&1 | grep -c '^[[:space:]]*Usage:' || true)"
if [ "$out" -gt 0 ]; then
  PASS=$((PASS + 1))
  log "PASS: one-off-command"
else
  FAIL=$((FAIL + 1))
  log "FAIL: one-off-command"
fi

set -e
if [ "${BUILD_SCREENSHOT}" = "1" ]; then
  log "Running optional screenshot variant check"
  set +e
  if docker run --rm -v "$tmpdir:/workspace" "$SHOTTED_IMAGE" bash -lc 'command -v wkhtmltopdf >/dev/null && echo present || echo absent'; then
    PASS=$((PASS + 1))
    log "PASS: screenshot-variant"
  else
    FAIL=$((FAIL + 1))
    log "FAIL: screenshot-variant"
  fi
  set -e
fi

log "Summary: PASS=${PASS} FAIL=${FAIL}"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi

log "All tests passed"
exit 0
