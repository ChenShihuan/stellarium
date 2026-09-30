#!/bin/bash
set -euo pipefail
test "$(id -un)" = root
payload="$(cd "$(dirname "$0")/.." && pwd)"
test -f "$payload/client/index.html"
test -f "$payload/client/privacy.html"
test ! -e /etc/skyinstrument-website
test ! -e /etc/systemd/system/skyinstrument-website.service
test ! -e /etc/logrotate.d/skyinstrument-website
test ! -e /srv/skyinstrument/website
install -d -m 0755 /etc/skyinstrument-website /srv/skyinstrument/website/releases/20260923 /srv/skyinstrument/website/acme
cp -R "$payload/client/." /srv/skyinstrument/website/releases/20260923/
find /srv/skyinstrument/website/releases/20260923 -type d -exec chmod 0755 {} +
find /srv/skyinstrument/website/releases/20260923 -type f -exec chmod 0644 {} +
ln -s releases/20260923 /srv/skyinstrument/website/current
install -m 0644 "$payload/deploy/nginx.conf" /etc/skyinstrument-website/nginx.conf
install -m 0644 "$payload/deploy/skyinstrument-website.service" /etc/systemd/system/skyinstrument-website.service
install -m 0644 "$payload/deploy/logrotate" /etc/logrotate.d/skyinstrument-website
systemd-analyze verify /etc/systemd/system/skyinstrument-website.service
systemctl daemon-reload
systemctl enable --now skyinstrument-website
systemctl is-active skyinstrument-website
curl -fsS --max-time 5 -H 'Host: skyinstrument.cn' http://127.0.0.1/ | grep -q '新ICP备2026008516号'
curl -fsS --max-time 5 http://127.0.0.1:8080/healthz
