#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ ${1:-} != --apply ]]; then
  printf '%s\n' 'Usage: sudo bash prepare-resource-server-operator.sh --apply' 'Creates locked-password skyops for non-privileged Workbench diagnostics; grants no sudo rights.'
  exit 0
fi
[[ $(id -u) == 0 ]] || { echo 'Root required' >&2; exit 1; }
source /etc/os-release
[[ $ID == alinux && $VERSION_ID == 3 ]] || { echo 'Unsupported OS' >&2; exit 1; }
if getent passwd skyops >/dev/null || getent group skyops >/dev/null || [[ -e /home/skyops || -L /home/skyops ]]; then
  echo 'Existing skyops identity or home; inspect instead of changing permissions' >&2
  exit 1
fi
useradd --create-home --user-group --shell /bin/bash --comment 'Skyinstrument non-privileged operator' skyops
chmod 0700 /home/skyops
id skyops
passwd -S skyops
printf '%s\n' 'No password, sudo grant, cloud role or public access was added.'
