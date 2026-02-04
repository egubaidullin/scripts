# UFW Sync for Docker & Nginx Proxy Manager

A production-ready Bash script to synchronize **UFW (Uncomplicated Firewall)** with **Docker** on Ubuntu 24.04+.

It solves the common security flaw where Docker bypasses UFW rules, exposing containers to the public internet. It is specifically designed for setups using **Nginx Proxy Manager (NPM)**, ensuring the Admin Port (81) is accessible **only** to whitelisted IPs, while keeping SSH and Web ports (80/443) open.

## 🚀 Features

*   **Docker Security Fix:** Manually patches `/etc/ufw/after.rules` to force Docker traffic through UFW.
*   **Whitelist-Only Admin Access:** The Admin Port (default: 81) is blocked for the world and allowed only for IPs in `allowed_ips.txt`.
*   **Anti-Lockout:** Automatically detects your current SSH IP and adds it to the whitelist before enabling the firewall.
*   **Auto-Detect SSH:** Reads `sshd_config` to find your actual SSH port (prevents lockout if you use a custom port).
*   **Cloudflare Support:** Automatically fetches and allows Cloudflare IPv4/IPv6 ranges on ports 80/443.
*   **Fail2Ban Integration:** Adds whitelisted IPs to Fail2Ban's `ignoreip` list to prevent accidental bans.
*   **Safe & Idempotent:** Can be run multiple times without duplicating rules or breaking configuration.

---

## ⚠️ Prerequisite: Switch to iptables-legacy (Critical)

**Why is this necessary?**
Ubuntu 24.04 uses `nftables` by default. However, Docker still relies heavily on `iptables`. When running in the default mode, Docker inserts its rules directly into the kernel, bypassing UFW entirely. This means `ufw deny 81` **will not work** for a Docker container.

To fix this, you must switch Ubuntu to use `iptables-legacy`. This ensures Docker and UFW share the same rule tables and UFW can correctly filter Docker traffic.

**Run these commands once before using the script:**

```bash
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
```

---

## 🛠 Installation & Usage

### 1. Setup Directories
Create the directory for the script and the config:

```bash
sudo mkdir -p /opt/ufw-sync
sudo mkdir -p /opt/configs
```

### 2. Create the Whitelist
Create the file `/opt/configs/allowed_ips.txt` and add your trusted IP addresses (one per line).

```bash
sudo nano /opt/configs/allowed_ips.txt
```
*Example content:*
```text
# My Home IP
203.0.113.15
# Office VPN
198.51.100.42
```

### 3. Install the Script
Save the script code into `/opt/ufw-sync/ufw-sync.sh` and make it executable.

```bash
sudo chmod +x /opt/ufw-sync/ufw-sync.sh
```

### 4. Run the Script
Run the script as root. It will detect your current IP, apply the Docker security patch, and enable UFW.

```bash
sudo /opt/ufw-sync/ufw-sync.sh
```

---

## ⚙️ Configuration

You can edit the variables at the top of `ufw-sync.sh` to match your environment:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `SSH_PORT` | Auto-detect | The port used for SSH. If auto-detect fails, it defaults to 22. |
| `ADMIN_PORT` | `81` | The port for Nginx Proxy Manager Admin UI. |
| `IP_FILE` | `/opt/configs/allowed_ips.txt` | Path to the whitelist file. |
| `DRY_RUN` | `0` | Set to `1` to print commands without executing them. |

---

## 🔍 How It Works

1.  **Detection:** The script identifies your current IP (via `SSH_CLIENT` or `who`) and ensures you are whitelisted to prevent locking yourself out.
2.  **Reset:** It performs `ufw reset` to clear old, potentially conflicting rules.
3.  **Patching:** It rewrites `/etc/ufw/after.rules` to include a `DOCKER-USER` chain that jumps to `ufw-user-forward`. This is the "magic" that makes Docker respect UFW.
4.  **Rules Application:**
    *   **SSH:** Allowed globally (protected by Fail2Ban).
    *   **HTTP/HTTPS:** Allowed globally (plus Cloudflare ranges).
    *   **Admin Port (81):** Allowed **only** for IPs in the whitelist (both `INPUT` for host and `FORWARD` for Docker).
5.  **Fail2Ban:** It generates a config file in `/etc/fail2ban/jail.d/` to ensure whitelisted IPs are never banned.

---

## ✅ Verification

After running the script, you can verify the security status:

**1. Check UFW Status:**
```bash
sudo ufw status verbose
```
*Look for `ALLOW IN` rules for your IP on port 81.*

**2. Check Docker Chain:**
```bash
sudo iptables -L DOCKER-USER -n --line-numbers
```
*You should see `ufw-user-forward` as the first rule, and `DROP` as the last rule.*

**3. Check Forwarding:**
```bash
sudo iptables -L ufw-user-forward -n
```
*You should see `ACCEPT` rules for your whitelisted IPs targeting port 81.*

---

## 🤖 Automation (Optional)

To automatically sync IPs (e.g., if you update the text file or want to fetch new Cloudflare IPs), add a cron job:

```bash
# Run every day at 4 AM
0 4 * * * /opt/ufw-sync/ufw-sync.sh > /dev/null 2>&1
```

## 📄 License

MIT License. Use at your own risk. Always ensure you have console access (VNC/KVM) to your server before modifying firewall rules.
