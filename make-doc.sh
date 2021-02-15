#! /usr/bin/env bash

set -euox pipefail

ROOT="${BASH_SOURCE[0]}"
if([ -h "${ROOT}" ]) then
  while([ -h "${ROOT}" ]) do ROOT=`readlink "${ROOT}"`; done
fi
ROOT=$(cd `dirname "${ROOT}"` && pwd)
cd "${ROOT}"

LDOC="${LDOC:-$(which ldoc)}" || true
if [ -z "${LDOC}" ]; then
  LDOC="$(which ldoc.lua)" || true
fi

if [ -z "${LDOC}" ]; then
  echo "Error: `ldoc' or `ldoc.lua' executable not found" >&2
  exit 1
fi

exec /usr/bin/env "${LDOC}" -c "${ROOT}/config.ld" "${ROOT}/crontab"
