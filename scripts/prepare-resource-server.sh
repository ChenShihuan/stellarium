#!/usr/bin/env bash
set -euo pipefail
umask 027

if [[ ${1:-} != --apply ]]; then
  printf '%s\n' 'Usage: sudo bash prepare-resource-server.sh --apply' 'Alibaba Cloud Linux 3 only. Installs a loopback-only staging service; no public ports or SSH changes.'
  exit 0
fi
[[ $(id -u) == 0 ]] || { echo 'Root required' >&2; exit 1; }
source /etc/os-release
[[ $ID == alinux && $VERSION_ID == 3 ]] || { echo 'Unsupported OS' >&2; exit 1; }
for target in /etc/skyinstrument /etc/systemd/system/skyinstrument-resources.service /srv/skyinstrument; do
  if [[ -e $target || -L $target ]]; then
    echo "Already exists; inspect instead of overwriting: $target" >&2
    exit 1
  fi
done
if ss -H -lnt | awk '{print $4}' | grep -Eq ':8080$'; then
  echo 'Port 8080 already occupied' >&2
  exit 1
fi
dnf -y install nginx curl tar
getent passwd nginx >/dev/null
install -d -m 0755 /srv/skyinstrument /srv/skyinstrument/releases
install -d -m 0750 -o root -g nginx /etc/skyinstrument
install -d -m 0700 /srv/skyinstrument/staging /var/backups/skyinstrument
cat > /etc/skyinstrument/nginx.conf <<'NGINX'
worker_processes 1;
pid /run/skyinstrument/nginx.pid;
error_log stderr warn;
events { worker_connections 256; }
http {
    access_log off;
    server_tokens off;
    sendfile on;
    keepalive_timeout 15;
    client_max_body_size 1k;
    client_body_temp_path /run/skyinstrument/client;
    proxy_temp_path /run/skyinstrument/proxy;
    fastcgi_temp_path /run/skyinstrument/fastcgi;
    uwsgi_temp_path /run/skyinstrument/uwsgi;
    scgi_temp_path /run/skyinstrument/scgi;
    server {
        listen 127.0.0.1:8080;
        server_name localhost;
        add_header X-Content-Type-Options nosniff always;
        add_header Cache-Control "no-store" always;
        location = /healthz {
            if ($request_method !~ ^(GET|HEAD)$) { return 405; }
            default_type application/json;
            return 200 '{"status":"staging","publicService":false}\n';
        }
        location / { return 404; }
    }
}
NGINX
chown root:nginx /etc/skyinstrument/nginx.conf
chmod 0640 /etc/skyinstrument/nginx.conf
cat > /etc/systemd/system/skyinstrument-resources.service <<'UNIT'
[Unit]
Description=Skyinstrument loopback staging service
After=network.target
[Service]
Type=simple
User=nginx
Group=nginx
RuntimeDirectory=skyinstrument
RuntimeDirectoryMode=0750
ExecStartPre=/usr/sbin/nginx -t -c /etc/skyinstrument/nginx.conf
ExecStart=/usr/sbin/nginx -c /etc/skyinstrument/nginx.conf -g "daemon off;"
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=/run/skyinstrument
CapabilityBoundingSet=
RestrictAddressFamilies=AF_UNIX AF_INET
UMask=0027
[Install]
WantedBy=multi-user.target
UNIT
chmod 0644 /etc/systemd/system/skyinstrument-resources.service
systemctl daemon-reload
systemctl enable --now skyinstrument-resources.service
for attempt in 1 2 3 4 5; do
  if curl -fsS --max-time 3 http://127.0.0.1:8080/healthz; then break; fi
  sleep 1
done
systemctl is-active --quiet skyinstrument-resources.service
curl -fsS --max-time 3 http://127.0.0.1:8080/healthz
[[ $(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:8080/) == 404 ]]
backup="/var/backups/skyinstrument/config-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
tar -czf "$backup" -C / etc/skyinstrument etc/systemd/system/skyinstrument-resources.service
sha256sum "$backup" > "$backup.sha256"
tar -tzf "$backup"
ss -lntp
printf '%s\n' 'Staging ready. Public HTTP/TLS and resource publishing remain disabled.'
