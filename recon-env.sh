#!/usr/bin/env bash
set -euo pipefail

for f in /workspace/config/*.env; do
  [ -f "$f" ] || continue
  set -a
  . "$f"
  set +a
done

if [ "$#" -eq 0 ]; then
  exec /usr/bin/env bash
else
  exec "$@"
fi
