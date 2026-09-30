#!/bin/bash
set -euo pipefail
test "$(id -un)" = root
release=${1:?Release identifier required}
[[ "$release" =~ ^[0-9]{8}-[a-z0-9-]+$ ]]
payload="$(cd "$(dirname "$0")/.." && pwd)"
root=/srv/skyinstrument/website
test ! -e "$root/releases/$release"
test ! -e "$root/current.next"
test -s "$payload/client/index.html"
test -s "$payload/client/privacy.html"
test -s "$payload/client/credits.html"
test -s "$payload/client/404.html"
install -d -m 0755 "$root/releases/$release"
cp -R "$payload/client/." "$root/releases/$release/"
find "$root/releases/$release" -type d -exec chmod 0755 {} +
find "$root/releases/$release" -type f -exec chmod 0644 {} +
previous=$(readlink "$root/current")
ln -s "releases/$release" "$root/current.next"
mv -Tf "$root/current.next" "$root/current"
for route in / /privacy /credits; do
    if ! curl -fsS --max-time 15 --resolve skyinstrument.cn:443:127.0.0.1 "https://skyinstrument.cn$route" -o /dev/null; then
        ln -s "$previous" "$root/current.rollback"
        mv -Tf "$root/current.rollback" "$root/current"
        exit 1
    fi
done
printf 'Published %s; previous release %s\n' "$release" "$previous"
