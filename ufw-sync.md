# ufw-sync

A firewall management script for Ubuntu 24.04 (legacy iptables) that enforces IP whitelisting, Docker routing rules, Cloudflare IP allowlisting, and Fail2Ban integration — all driven by a single config file.

---

## Features

- **Config-driven** — all ports, flags, and paths live in `ufw-sync.conf`; the script itself never needs editing
- **Public vs. whitelist ports** — cleanly separate what is open to everyone vs. what requires a trusted IP
- **Anti-lockout protection** — auto-detects your current SSH session IP via three fallback methods and adds it to the whitelist before resetting UFW
- **Docker-aware** — writes correct `after.rules` (NAT MASQUERADE + DOCKER-USER chain) so containers retain internet access through UFW
- **Cloudflare IP sync** — fetches live IPv4 and IPv6 ranges from Cloudflare and allows them on public ports
- **Fail2Ban integration** — syncs `ignoreip` from the whitelist file; restarts only when the config actually changes
- **Dry-run mode** — preview every command without applying anything
- **Automatic backups** — saves `after.rules` before each run, keeps the last 10 copies

---

## Requirements

| Dependency | Notes |
|---|---|
| Ubuntu 24.04 | Tested on; should work on 22.04 |
| `ufw` | With legacy iptables (`iptables-legacy`) |
| `curl` | For Cloudflare IP fetch |
| `docker` _(optional)_ | For Docker network subnet rules |
| `fail2ban` _(optional)_ | For `ignoreip` sync |

Switch to legacy iptables if not already done:
```bash
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
```

---

## File Layout

```
/opt/ufw-sync/
├── ufw-sync.sh          # Main script (do not edit for config changes)
└── backups/             # Auto-saved after.rules backups

/etc/ufw-sync/
└── ufw-sync.conf        # ← Edit this to configure everything

/opt/configs/
└── allowed_ips.txt      # Whitelist — one IP or CIDR per line
```

---

## Installation

```bash
# 1. Create directories
sudo mkdir -p /opt/ufw-sync /etc/ufw-sync /opt/configs

# 2. Copy files
sudo cp ufw-sync.sh /opt/ufw-sync/ufw-sync.sh
sudo cp ufw-sync.conf /etc/ufw-sync/ufw-sync.conf

# 3. Set permissions
sudo chmod 700 /opt/ufw-sync/ufw-sync.sh
sudo chmod 600 /etc/ufw-sync/ufw-sync.conf

# 4. Add your trusted IPs to the whitelist
sudo nano /opt/configs/allowed_ips.txt
```

---

## Configuration

All settings live in `/etc/ufw-sync/ufw-sync.conf`.

```bash
# SSH port — leave empty to auto-detect from /etc/ssh/sshd_config
SSH_PORT=""

# Ports open to everyone (space-separated)
PUBLIC_PORTS_TCP="80 443"
PUBLIC_PORTS_UDP=""

# Ports open only to IPs in allowed_ips.txt
WHITELIST_PORTS_TCP="81 8080 8443"
WHITELIST_PORTS_UDP=""

# Paths
IP_FILE="/opt/configs/allowed_ips.txt"
LOG_FILE="/var/log/ufw_sync.log"
BACKUP_DIR="/opt/ufw-sync/backups"

# Features
ENABLE_CLOUDFLARE=1        # Sync Cloudflare IP ranges
ENABLE_DOCKER_NETWORKS=1   # Auto-add Docker subnet rules
DOCKER_MASQUERADE_RANGE="172.16.0.0/12"
ENABLE_FAIL2BAN=1          # Sync whitelist → fail2ban ignoreip

# 1 = preview only, no changes applied
DRY_RUN=0
```

### Whitelist file format (`allowed_ips.txt`)

```
# Office
203.0.113.10
198.51.100.0/24

# Home
203.0.113.55
```

Lines starting with `#` and blank lines are ignored.

---

## Usage

**Preview (no changes applied):**
```bash
sudo /opt/ufw-sync/ufw-sync.sh --dry-run
```

**Apply:**
```bash
sudo /opt/ufw-sync/ufw-sync.sh
```

**Check the log:**
```bash
tail -f /var/log/ufw_sync.log
```

**Override config file path:**
```bash
sudo CONFIG_FILE=/tmp/test.conf /opt/ufw-sync/ufw-sync.sh --dry-run
```

---

## Automation (cron / systemd)

### Cron — run daily at 3 AM

```bash
sudo crontab -e
```
```
0 3 * * * /opt/ufw-sync/ufw-sync.sh >> /var/log/ufw_sync.log 2>&1
```

### Systemd timer

`/etc/systemd/system/ufw-sync.service`:
```ini
[Unit]
Description=UFW Sync
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/ufw-sync/ufw-sync.sh
StandardOutput=append:/var/log/ufw_sync.log
StandardError=append:/var/log/ufw_sync.log
```

`/etc/systemd/system/ufw-sync.timer`:
```ini
[Unit]
Description=UFW Sync — daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ufw-sync.timer
```

---

## How It Works

Each run follows this sequence:

1. Load `/etc/ufw-sync/ufw-sync.conf`
2. Detect current SSH session IP (3 fallback methods: `SSH_CLIENT` → `who` → `ss`)
3. Auto-add detected IP to whitelist to prevent lockout
4. Back up `/etc/ufw/after.rules`
5. Rewrite `after.rules` with correct NAT and DOCKER-USER rules
6. Reset UFW and set `deny incoming` / `allow outgoing`
7. Open SSH port globally
8. Open public ports (TCP/UDP) for everyone
9. Open whitelist-only ports for each IP in `allowed_ips.txt`
10. Allow Cloudflare IP ranges on public ports (if enabled)
11. Allow Docker subnet IPs (if enabled)
12. Enable UFW and reload
13. Sync Fail2Ban `ignoreip` (if enabled, only if changed)

---

## Docker Notes

The script rewrites `/etc/ufw/after.rules` on every run to ensure Docker containers can reach the internet through UFW without conflict:

- **NAT MASQUERADE** on `172.16.0.0/12` for outbound container traffic
- **ESTABLISHED,RELATED** conntrack rule so response packets are not dropped
- **DOCKER-USER** chain linked to `ufw-user-forward` for UFW-managed forwarding rules

> **Important:** If you manually edit `after.rules`, your changes will be overwritten on the next run. Use the config file or extend the script instead.

---

## Troubleshooting

**Locked out after running the script**

Boot into recovery or use a console session and run:
```bash
sudo ufw disable
sudo ufw reset
```
Then add your IP to `allowed_ips.txt` and re-run with `--dry-run` first.

**Cloudflare IPs not updating**

Check network access from the server:
```bash
curl -fsS https://www.cloudflare.com/ips-v4
```
If blocked, set `ENABLE_CLOUDFLARE=0` in the config.

**Docker containers have no internet access**

Verify `after.rules` was written correctly:
```bash
sudo cat /etc/ufw/after.rules
sudo iptables -t nat -L POSTROUTING -n -v
```
Ensure you are using `iptables-legacy`, not `nftables`.

**Current IP not detected**

If running via a non-SSH session (console, tmux detached), detection may fail. Add your IP manually to `allowed_ips.txt` before running.

---

## Security Notes

- `allowed_ips.txt` and the log file are created with `chmod 600`
- The config file should also remain `600` (set during installation)
- The script validates IP format before applying rules — malformed entries are logged and skipped
- Fail2Ban config is only rewritten when `ignoreip` actually changes, avoiding unnecessary restarts

---

## License

MIT
