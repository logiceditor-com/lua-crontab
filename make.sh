#! /usr/bin/env bash

set -euox pipefail

echo "----> Generating rockspec"
lua etc/rockspec/generate.lua scm-1 > rockspec/lua-crontab-scm-1.rockspec

reinstall() {
  LUAROCKS="$1"

  echo "----> Remove a rock"
  ${LUAROCKS} remove --force lua-crontab || true

  echo "----> Making rocks"
  "$LUAROCKS" make rockspec/lua-crontab-scm-1.rockspec
}

if [[ "$@" == *--local* ]] ; then
  reinstall luarocks
else
  reinstall "sudo luarocks"
fi

if [[ "$@" != *--no-restart* ]] ; then
  echo "----> Restarting multiwatch and LJ2"
  sudo killall multiwatch || true ; sudo killall luajit2 || true
fi

echo "----> OK"
