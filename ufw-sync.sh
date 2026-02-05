#!/usr/bin/env bash
# /opt/ufw-sync/ufw-sync.sh
# Fixed: Completely overwrites after.rules to prevent syntax errors on re-runs.
set -euo pipefail

# -------------------------
# Configuration
# -------------------------
DETECTED_SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | head -n 1 || echo "22")
SSH_PORT=${SSH_PORT:-$DETECTED_SSH_PORT}
ADMIN_PORT=${ADMIN_PORT:-81}
IP_FILE="/opt/configs/allowed_ips.txt"
LOG_FILE="/var/log/ufw_sync.log"
CLOUDFLARE_IPV4_URL="https://www.cloudflare.com/ips-v4"
CLOUDFLARE_IPV6_URL="https://www.cloudflare.com/ips-v6"
DRY_RUN=${DRY_RUN:-0}
# -------------------------

# Helpers
log()  { echo "[$(date --iso-8601=seconds)] $*" | tee -a "$LOG_FILE"; }
err()  { echo "[$(date --iso-8601=seconds)] ERROR: $*" | tee -a "$LOG_FILE" >&2; }
info() { echo "[$(date --iso-8601=seconds)] INFO: $*" | tee -a "$LOG_FILE"; }
plan() { if [ "$DRY_RUN" -eq 1 ]; then echo "DRY-RUN: $*"; else eval "$@"; fi; }

mkdir -p "$(dirname "$IP_FILE")" /opt/ufw-sync
touch "$IP_FILE" "$LOG_FILE"
chmod 600 "$IP_FILE" "$LOG_FILE"

log "ufw-sync starting. SSH Port: $SSH_PORT"

# 1. Detect Current IP
CURRENT_IP=""
if [ -n "${SSH_CLIENT-}" ]; then
  CURRENT_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
elif [ -n "${SUDO_USER-}" ]; then
  CURRENT_IP=$(who -m 2>/dev/null | awk '{print $NF}' | tr -d '()' || true)
fi

if [ -n "$CURRENT_IP" ]; then
  info "Detected current IP: $CURRENT_IP"
  if ! grep -Fxq "$CURRENT_IP" "$IP_FILE"; then
    echo "$CURRENT_IP" >> "$IP_FILE"
    info "Auto-added $CURRENT_IP to whitelist"
  fi
else
  err "WARNING: Could not detect current IP. Ensure SSH_PORT is correct!"
fi

# 2. Reset UFW
log "Resetting UFW..."
plan "ufw --force reset"
plan "ufw default deny incoming"
plan "ufw default allow outgoing"

# 3. OVERWRITE after.rules (Fixes 'Bad argument *filter' error)
# We completely replace the file content to ensure valid syntax.
info "Configuring /etc/ufw/after.rules for Docker..."
if [ "$DRY_RUN" -eq 0 ]; then
  cat > /etc/ufw/after.rules <<EOF
# /etc/ufw/after.rules
# Rules that should be run after the ufw command line added rules. Custom
# rules should be added to one of these chains:
#   ufw-before-input
#   ufw-before-output
#   ufw-before-forward

# Don't delete these required lines, otherwise there will be errors
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]

# Link DOCKER-USER to ufw-user-forward
-A DOCKER-USER -j ufw-user-forward

# Allow internal Docker networks
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

# Allow UDP specific ports (DNS/DHCP)
-A DOCKER-USER -p udp -m udp --sport 53 --dport 1024:65535 -j RETURN
-A DOCKER-USER -p udp -m udp --dport 53 -j RETURN
-A DOCKER-USER -p udp -m udp --dport 67 -j RETURN
-A DOCKER-USER -p udp -m udp --dport 68 -j RETURN

# Allow valid TCP packets
-A DOCKER-USER -j RETURN -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 192.168.0.0/16
-A DOCKER-USER -j RETURN -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 10.0.0.0/8
-A DOCKER-USER -j RETURN -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -d 172.16.0.0/12

# Drop everything else going to Docker (unless allowed by ufw route)
-A DOCKER-USER -j DROP

COMMIT
EOF
  info "after.rules rewritten successfully"
fi

# 4. Allow SSH & Current IP (Anti-Lockout)
if [ -n "$CURRENT_IP" ]; then
  plan "ufw allow from $CURRENT_IP to any comment 'ANTI-LOCKOUT'"
fi
plan "ufw allow ${SSH_PORT}/tcp comment 'SSH Global'"
plan "ufw allow 80/tcp"
plan "ufw allow 443/tcp"
plan "ufw route allow 80/tcp"
plan "ufw route allow 443/tcp"
plan "ufw allow in on lo"

# 5. Apply Admin Whitelist & Docker Routes
info "Applying Admin Whitelist..."
if [ -f "$IP_FILE" ]; then
  while IFS= read -r ip || [ -n "$ip" ]; do
    case "$ip" in ''|\#*) continue ;; esac
    clean_ip=$(echo "$ip" | xargs)

    # Allow Admin Port (Host)
    plan "ufw allow from ${clean_ip} to any port ${ADMIN_PORT} proto tcp comment 'admin whitelist'"
    # Allow Docker Routing (NPM Container)
    plan "ufw route allow from ${clean_ip} to any port ${ADMIN_PORT} proto tcp comment 'admin whitelist docker'"
  done < "$IP_FILE"
fi

# 6. Cloudflare & Docker Networks
if command -v curl &>/dev/null; then
  info "Updating Cloudflare IPs..."
  for ip in $(curl -fsS "$CLOUDFLARE_IPS_V4" || true); do
    [ -z "$ip" ] && continue
    plan "ufw allow from ${ip} to any port 80,443 proto tcp"
    plan "ufw route allow from ${ip} to any port 80,443 proto tcp" # <-- ДОБАВИТЬ ЭТО
  done
fi



if command -v docker &>/dev/null; then
  docker network ls --format '{{.Name}}' | while read -r net; do
    subnets=$(docker network inspect "$net" --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null || true)
    for s in $subnets; do
      [ -n "$s" ] && plan "ufw allow from ${s} comment 'docker network ${net}'" >/dev/null
    done
  done
fi

# 7. Enable UFW
log "Enabling UFW..."
plan "ufw --force enable"
plan "ufw reload"

# 8. Fail2Ban
if command -v fail2ban-client &>/dev/null; then
  info "Configuring fail2ban..."
  NEW_IGNORE=""
  if [ -f "$IP_FILE" ]; then
    while IFS= read -r ip || [ -n "$ip" ]; do
      case "$ip" in ''|\#*) continue ;; esac
      clean_ip=$(echo "$ip" | xargs)
      NEW_IGNORE="${NEW_IGNORE} ${clean_ip}"
    done < "$IP_FILE"
  fi

  if [ -n "$NEW_IGNORE" ]; then
    mkdir -p "/etc/fail2ban/jail.d"
    echo -e "[DEFAULT]\nignoreip = 127.0.0.1/8 ::1 ${NEW_IGNORE}" > "/etc/fail2ban/jail.d/ufw-sync-ignoreip.conf"
    if [ "$DRY_RUN" -eq 0 ] && fail2ban-client -t >/dev/null 2>&1; then
      systemctl restart fail2ban
    fi
  fi
fi

log "Done. Access secured."
exit 0
