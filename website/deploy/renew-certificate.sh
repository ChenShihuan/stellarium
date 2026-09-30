#!/bin/bash
set -euo pipefail
test "$(id -un)" = root
umask 077
/root/.skyinstrument-acme/acme.sh --cron --home /root/.skyinstrument-acme
/usr/local/sbin/skyinstrument-install-certificate
