#!/bin/bash
set -euo pipefail
test "$(id -un)" = root
payload="$(cd "$(dirname "$0")" && pwd)"
test -s /root/.skyinstrument-acme/skyinstrument.cn_ecc/fullchain.cer
test ! -e /usr/local/sbin/skyinstrument-install-certificate
test ! -e /usr/local/sbin/skyinstrument-renew-certificate
test ! -e /etc/systemd/system/skyinstrument-certificate.service
test ! -e /etc/systemd/system/skyinstrument-certificate.timer
backup=$(mktemp -d /var/backups/skyinstrument/website-tls-XXXXXXXX)
chmod 0700 "$backup"
cp -p /etc/skyinstrument-website/nginx.conf "$backup/nginx.conf"
install -m 0750 "$payload/install-certificate.sh" /usr/local/sbin/skyinstrument-install-certificate
install -m 0750 "$payload/renew-certificate.sh" /usr/local/sbin/skyinstrument-renew-certificate
/usr/local/sbin/skyinstrument-install-certificate
install -m 0644 "$payload/nginx-tls.conf" /etc/skyinstrument-website/nginx.conf
if ! /usr/sbin/nginx -t -c /etc/skyinstrument-website/nginx.conf; then
    cp -p "$backup/nginx.conf" /etc/skyinstrument-website/nginx.conf
    exit 1
fi
systemctl reload skyinstrument-website
curl -fsS --max-time 15 --retry 5 --retry-delay 1 --retry-connrefused --resolve skyinstrument.cn:443:127.0.0.1 https://skyinstrument.cn/ -o /dev/null
install -m 0644 "$payload/skyinstrument-certificate.service" /etc/systemd/system/skyinstrument-certificate.service
install -m 0644 "$payload/skyinstrument-certificate.timer" /etc/systemd/system/skyinstrument-certificate.timer
systemd-analyze verify /etc/systemd/system/skyinstrument-certificate.service /etc/systemd/system/skyinstrument-certificate.timer
systemctl daemon-reload
systemctl enable --now skyinstrument-certificate.timer
systemctl start --no-block skyinstrument-certificate.service
systemctl is-active skyinstrument-website skyinstrument-certificate.timer
