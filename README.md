# zerotrace
linux-no-traces

This script is designed for scenarios where minimal persistent logging is desired: temporary servers, testing environments, penetration testing labs, privacy-focused personal setups, or educational anti-forensics research.

⚠️ **Important Warning**  

This script significantly reduces or eliminates system logging and forensic artifacts. It can impair security auditing, monitoring, troubleshooting, and compliance.  
Use **only** on systems you fully own and control. It may violate organizational policies, hosting provider terms, or legal requirements in certain contexts. Apply at your own risk.

## zerotrace.sh

The script performs the following actions:

- Stops, disables, and removes `rsyslog` (if possible)
- Configures `systemd-journald` for volatile (in-memory only) storage with strict limits (1M total, 256K per file, 30-second retention)
- Clears existing journal logs
- Stops and disables `auditd`, removes its logs
- Securely overwrites and deletes login accounting files (`wtmp`, `btmp`, `lastlog`, `faillog`)
- Deletes all shell history files (`.bash_history`, `.*_history`) in `/home` and `/root`
- Permanently disables Bash history recording for all users and future sessions
- Disables last login information display (via PAM)
- Clears `/tmp` and `/var/tmp`, mounts them as tmpfs (in RAM, wiped on reboot)
- Sets SSH logging to minimal level (`LogLevel QUIET`)
- Adds a cron job to overwrite and delete key log files every 5 minutes
