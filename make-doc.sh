#! /bin/bash -e

set -euo pipefail

LDOC="$(which ldoc)" || true
if [ -z "${LDOC}" ]; then
  LDOC="$(which ldoc.lua)" || true
fi

if [ -z "${LDOC}" ]; then
  echo "Error: `ldoc' or `ldoc.lua' executable not found" >&2
  exit 1
fi

exec /usr/bin/env "${LDOC}" .
