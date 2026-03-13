#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./agent-run.sh shell
  ./agent-run.sh run [command ...]
  ./agent-run.sh check

Environment variables:
  IMAGE            Image tag (default: kali-recon:test)
  WORKSPACE        Host path to mount at /workspace (default: current working directory)
  AGENT_USER       Optional Docker --user value (default: host uid:gid)
  AGENT_ROOT=1     Run as root in container
  AGENT_TTY=1      Allocate a TTY for shell-style commands (default when interactive)
  AGENT_NETRAW=1    Add NET_RAW + NET_ADMIN capabilities (for tcpdump)
  AGENT_BUILD_DEFAULT=1 Run test-image build step (for check mode, default: 1)
  SKIP_NETWORK_CHECK=1 Skip external network checks in test mode
  AGENT_REPORT=1   Emit machine-readable JSON for check mode
EOF
}

IMAGE="${IMAGE:-kali-recon:test}"
WORKSPACE="${WORKSPACE:-$PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_IMAGE_SH="${SCRIPT_DIR}/test-image.sh"
AGENT_TTY="${AGENT_TTY:-}"
AGENT_ROOT="${AGENT_ROOT:-0}"
AGENT_NETRAW="${AGENT_NETRAW:-0}"
AGENT_BUILD_DEFAULT="${AGENT_BUILD_DEFAULT:-1}"
SKIP_NETWORK_CHECK="${SKIP_NETWORK_CHECK:-0}"
AGENT_REPORT="${AGENT_REPORT:-0}"
AGENT_UID="${AGENT_UID:-$(id -u)}"
AGENT_GID="${AGENT_GID:-$(id -g)}"
AGENT_USER="${AGENT_USER:-${AGENT_UID}:${AGENT_GID}}"

if [ "$AGENT_ROOT" = "1" ]; then
  AGENT_USER="root"
fi

CAPS=()
if [ "$AGENT_NETRAW" = "1" ]; then
  CAPS+=(--cap-add=NET_RAW --cap-add=NET_ADMIN)
fi

run_container() {
  local -a run_cmd=(docker run --rm -i --user "$AGENT_USER")
  if [ "${AGENT_TTY}" = "1" ] || [ "${AGENT_TTY}" = "" ] && [ -t 0 ]; then
    run_cmd+=(-t)
  fi

  if [ ${#CAPS[@]} -gt 0 ]; then
    run_cmd+=("${CAPS[@]}")
  fi

  run_cmd+=(-v "$WORKSPACE:/workspace" -e HOME=/tmp "$IMAGE" "$@")
  "${run_cmd[@]}"
}

run_check() {
  if [ "${AGENT_REPORT}" = "1" ]; then
    local tmp_report
    tmp_report="$(mktemp)"

    set +e
    IMAGE="$IMAGE" BUILD_DEFAULT="$AGENT_BUILD_DEFAULT" SKIP_NETWORK_CHECK="$SKIP_NETWORK_CHECK" \
      "$TEST_IMAGE_SH" > "$tmp_report" 2>&1
    local check_rc=$?
    set -e

    local pass fail
    pass="$(sed -n 's/.*Summary: PASS=\([0-9][0-9]*\) FAIL=\([0-9][0-9]*\).*/\1/p' "$tmp_report" | tail -n 1)"
    fail="$(sed -n 's/.*Summary: PASS=\([0-9][0-9]*\) FAIL=\([0-9][0-9]*\).*/\2/p' "$tmp_report" | tail -n 1)"
    pass="${pass:-0}"
    fail="${fail:-0}"

    cat <<JSON
{
  "command": "check",
  "image": "${IMAGE}",
  "result": "$([ "$check_rc" -eq 0 ] && echo pass || echo fail)",
  "pass": ${pass},
  "fail": ${fail},
  "network_check_skipped": $([ "$SKIP_NETWORK_CHECK" = "1" ] && echo true || echo false)
}
JSON
    cat "$tmp_report" >&2
    rm -f "$tmp_report"
    return "$check_rc"
  fi

  IMAGE="$IMAGE" BUILD_DEFAULT="$AGENT_BUILD_DEFAULT" SKIP_NETWORK_CHECK="$SKIP_NETWORK_CHECK" \
    "$TEST_IMAGE_SH"
}

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

case "$1" in
  shell)
    shift
    run_container bash
    ;;
  run)
    shift
    if [ $# -eq 0 ]; then
      set -- bash
    fi
    run_container "$@"
    ;;
  check)
    run_check
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    run_container "$@"
    ;;
esac
