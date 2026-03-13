#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- bash
fi

mkdir -p /workspace/input /workspace/output /workspace/config /workspace/tmp

exec /usr/local/bin/tini -- "$@"
