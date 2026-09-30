#!/usr/bin/env bash
set -euo pipefail
umask 077

mode=${1:-}
if [[ $mode != --prepare && $mode != --apply ]]; then
  printf '%s\n' 'Usage: update-resource-server-security.sh --prepare | --apply BACKUP_DIRECTORY' 'Alibaba Cloud Linux 3 security updates only. Does not reboot; requires an approved maintenance window.'
  exit 0
fi
[[ $(id -u) == 0 ]] || { echo 'Root required' >&2; exit 1; }
source /etc/os-release
[[ $ID == alinux && $VERSION_ID == 3 ]] || { echo 'Unsupported OS' >&2; exit 1; }
options=(--disablerepo='*' --enablerepo=alinux3-os,alinux3-updates,alinux3-module,alinux3-plus,alinux3-powertools --setopt=gpgcheck=1 --setopt=installonly_limit=3)

if [[ $mode == --prepare ]]; then
  backup="/var/backups/skyinstrument/security-$(date -u +%Y%m%dT%H%M%SZ)"
  [[ ! -e $backup ]] || { echo 'Backup already exists' >&2; exit 1; }
  install -d -m 0700 "$backup"
  tar --acls --xattrs -czf "$backup/configuration.tar.gz" -C / etc srv/skyinstrument
  tar -tzf "$backup/configuration.tar.gz" >/dev/null
  (cd "$backup" && sha256sum configuration.tar.gz > configuration.sha256)
  rpm -qa | sort > "$backup/packages-before.txt"
  uname -r > "$backup/kernel-before.txt"
  cat /proc/sys/kernel/random/boot_id > "$backup/boot-id-before.txt"
  grubby --default-kernel > "$backup/default-kernel-before.txt"
  systemctl list-unit-files --state=enabled > "$backup/enabled-services-before.txt"
  dnf "${options[@]}" --refresh updateinfo summary --security > "$backup/advisories-before.txt" 2>&1
  set +e
  dnf "${options[@]}" upgrade-minimal --security --assumeno > "$backup/transaction-preview.txt" 2>&1
  preview_status=$?
  set -e
  printf '%s\n' "$preview_status" > "$backup/preview-exit-code.txt"
  printf 'Backup: %s\nPreview exit code: %s\n' "$backup" "$preview_status"
  cat "$backup/advisories-before.txt" "$backup/transaction-preview.txt"
  exit 0
fi

backup=${2:?Backup directory required}
[[ $backup == /var/backups/skyinstrument/security-* && -d $backup && ! -L $backup ]] || exit 2
[[ ! -e $backup/apply-started ]] || { echo 'Update was already started; inspect transaction history instead of retrying' >&2; exit 1; }
(cd "$backup" && sha256sum -c configuration.sha256)
sshd -t
systemctl is-active --quiet skyinstrument-resources
date -Is > "$backup/apply-started"
exec > >(tee -a "$backup/update.log") 2>&1
trap 'result=$?; printf "%s\n" "$result" > "$backup/apply-exit-code.txt"' EXIT
dnf "${options[@]}" -y upgrade-minimal --security
sshd -t
/usr/sbin/nginx -t -c /etc/skyinstrument/nginx.conf
rpm -qa | sort > "$backup/packages-after.txt"
dnf "${options[@]}" updateinfo summary --security > "$backup/advisories-after.txt" 2>&1
dnf history info last > "$backup/transaction-result.txt"
cat "$backup/advisories-after.txt"
printf '%s\n' 'Security transaction completed. Check service restarts and reboot requirements separately.'
