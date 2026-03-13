#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  set -- bash
fi

if [ ! -d /workspace ]; then
  if ! mkdir -p /workspace 2>/dev/null; then
    echo "WARN: /workspace is not writable in this runtime context." >&2
  fi
fi

for d in input output config tmp; do
  if [ ! -d "/workspace/$d" ]; then
    if ! mkdir -p "/workspace/$d" 2>/dev/null; then
      echo "WARN: unable to create /workspace/$d. Ensure the bind-mounted /workspace subdirectories are present and writable." >&2
    fi
  fi
done

exec /usr/bin/tini -- "$@"
