#!/bin/bash
set -euo pipefail
test "$(id -un)" = root
umask 077
source_dir=/root/.skyinstrument-acme/skyinstrument.cn_ecc
target=/etc/skyinstrument-website/tls
openssl x509 -in "$source_dir/fullchain.cer" -noout -checkend 86400
openssl x509 -in "$source_dir/fullchain.cer" -noout -checkhost skyinstrument.cn
openssl x509 -in "$source_dir/fullchain.cer" -noout -checkhost www.skyinstrument.cn
certificate_key=$(openssl x509 -in "$source_dir/fullchain.cer" -pubkey -noout | openssl sha256)
private_key=$(openssl pkey -in "$source_dir/skyinstrument.cn.key" -pubout | openssl sha256)
test "$certificate_key" = "$private_key"
install -d -o root -g nginx -m 0750 "$target"
if cmp -s "$source_dir/fullchain.cer" "$target/current/fullchain.pem" && cmp -s "$source_dir/skyinstrument.cn.key" "$target/current/privkey.pem"; then
    exit 0
fi
release=$(mktemp -d "$target/cert-XXXXXXXX")
chown root:nginx "$release"
chmod 0750 "$release"
install -o root -g nginx -m 0640 "$source_dir/fullchain.cer" "$release/fullchain.pem"
install -o root -g nginx -m 0640 "$source_dir/skyinstrument.cn.key" "$release/privkey.pem"
previous=$(readlink "$target/current" || true)
ln -s "$(basename "$release")" "$target/current.next"
mv -Tf "$target/current.next" "$target/current"
if /usr/sbin/nginx -t -c /etc/skyinstrument-website/nginx.conf && systemctl reload skyinstrument-website; then
    exit 0
fi
if [ -n "$previous" ]; then
    ln -s "$previous" "$target/current.rollback"
    mv -Tf "$target/current.rollback" "$target/current"
    /usr/sbin/nginx -t -c /etc/skyinstrument-website/nginx.conf && systemctl reload skyinstrument-website
fi
exit 1
