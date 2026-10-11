#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ ${1:-} != --apply ]]; then
  printf '%s\n' 'Usage: sudo bash enable-resource-server-audit.sh --apply' 'Enables existing auditd and watches critical configuration changes; no SSH, package or firewall changes.'
  exit 0
fi
[[ $(id -u) == 0 ]] || { echo 'Root required' >&2; exit 1; }
source /etc/os-release
[[ $ID == alinux && $VERSION_ID == 3 ]] || { echo 'Unsupported OS' >&2; exit 1; }
rpm -q audit >/dev/null
rules=/etc/audit/rules.d/zz-skyinstrument.rules
[[ ! -e $rules && ! -L $rules ]] || { echo 'Rules already exist; inspect instead of overwriting' >&2; exit 1; }
for target in /etc/ssh /etc/sudoers /etc/passwd /etc/group /etc/skyinstrument /etc/systemd/system/skyinstrument-resources.service; do
  [[ -e $target ]] || { echo "Missing target: $target" >&2; exit 1; }
done
if grep -Eq '^[[:space:]]*(-e[[:space:]]+2|-a[[:space:]]+(never,task|task,never))' /etc/audit/rules.d/*.rules; then
  echo 'Existing audit policy requires manual review' >&2
  exit 1
fi
backup="/var/backups/skyinstrument/audit-$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$backup"
cp -a /etc/audit "$backup/"
systemctl is-enabled auditd > "$backup/previous-enabled.txt" || true
systemctl is-active auditd > "$backup/previous-active.txt" || true
cat > "$rules" <<'RULES'
-w /etc/ssh -p wa -k sky_ssh
-w /etc/sudoers -p wa -k sky_identity
-w /etc/passwd -p wa -k sky_identity
-w /etc/group -p wa -k sky_identity
-w /etc/skyinstrument -p wa -k sky_resources
-w /etc/systemd/system/skyinstrument-resources.service -p wa -k sky_service
RULES
chmod 0600 "$rules"
systemctl enable --now auditd
augenrules --load
systemctl is-active --quiet auditd
auditctl -l
auditctl -s
printf 'Backup: %s\n' "$backup"
printf '%s\n' 'Audit enabled; existing rotation policy retained. No all-command recording and no remote log export.'
