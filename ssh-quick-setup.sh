#!/bin/bash

# ==============================================================================
# Script Name: ssh-quick-setup.sh
# Description: Automates SSH key generation and client configuration.
#              Cross-platform: macOS and Linux. Handles password-based servers.
# Usage:       ./ssh-quick-setup.sh
# ==============================================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}========================================="
echo -e "   SSH Quick Setup & Config Generator"
echo -e "=========================================${NC}"

# ------------------------------------------------------------------------------
# 0. Dependency check
# ------------------------------------------------------------------------------
MISSING_DEPS=()
for cmd in ssh ssh-keygen; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required commands: ${MISSING_DEPS[*]}${NC}"
    echo "Install OpenSSH and try again."
    exit 1
fi

# Detect OS for macOS-specific behaviour
OS_TYPE="$(uname -s)"

# Ensure ~/.ssh directory exists
if [ ! -d "$HOME/.ssh" ]; then
    echo -e "${GREEN}Creating ~/.ssh directory...${NC}"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
fi

# ------------------------------------------------------------------------------
# 1. Interactive Input
# ------------------------------------------------------------------------------
read -p "Enter Host Alias (e.g., my-vps): " HOST_ALIAS
if [ -z "$HOST_ALIAS" ]; then
    echo -e "${RED}Error: Host Alias cannot be empty.${NC}"
    exit 1
fi

read -p "Enter Server IP Address or Hostname: " SERVER_IP
if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Error: IP Address cannot be empty.${NC}"
    exit 1
fi

# Validated port input
while true; do
    read -p "Enter SSH Port [default: 22]: " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then
        break
    else
        echo -e "${RED}Invalid port. Enter a number between 1 and 65535.${NC}"
    fi
done

read -p "Enter SSH Username [default: root]: " SSH_USER
SSH_USER=${SSH_USER:-root}

KEY_NAME="${HOST_ALIAS}_ed25519"
KEY_PATH="$HOME/.ssh/${KEY_NAME}"

# ------------------------------------------------------------------------------
# Summary Confirmation
# ------------------------------------------------------------------------------
echo -e "\n${CYAN}--- Configuration Summary ---${NC}"
echo "  Host Alias : $HOST_ALIAS"
echo "  IP/Host    : $SERVER_IP"
echo "  Port       : $SSH_PORT"
echo "  Username   : $SSH_USER"
echo "  Key Path   : $KEY_PATH"
echo -e "${CYAN}-----------------------------${NC}"
read -p "Proceed with setup? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Operation cancelled by user."
    exit 0
fi

# ------------------------------------------------------------------------------
# 2. Generate SSH Key
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}[1/4] Generating ed25519 SSH key...${NC}"
if [ -f "$KEY_PATH" ]; then
    echo -e "${YELLOW}Key ${KEY_PATH} already exists. Skipping generation.${NC}"
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$HOST_ALIAS" -N ""
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to generate key.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Key generated: ${KEY_PATH}${NC}"
fi

# ------------------------------------------------------------------------------
# 3. Copy Public Key to Server
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}[2/4] Copying public key to server...${NC}"
echo -e "${CYAN}You will be prompted for the server password.${NC}"

COPY_SUCCESS=false

# Try ssh-copy-id first (available on Linux; may be absent on macOS)
if command -v ssh-copy-id &>/dev/null; then
    ssh-copy-id -i "${KEY_PATH}.pub" -p "$SSH_PORT" "${SSH_USER}@${SERVER_IP}"
    [ $? -eq 0 ] && COPY_SUCCESS=true
fi

# macOS fallback (or if ssh-copy-id failed)
if [ "$COPY_SUCCESS" = false ]; then
    echo -e "${YELLOW}ssh-copy-id unavailable or failed. Using manual fallback...${NC}"
    PUB_KEY="$(cat "${KEY_PATH}.pub")"
    ssh -p "$SSH_PORT" "${SSH_USER}@${SERVER_IP}" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
         echo '${PUB_KEY}' >> ~/.ssh/authorized_keys && \
         chmod 600 ~/.ssh/authorized_keys"
    if [ $? -eq 0 ]; then
        COPY_SUCCESS=true
    else
        echo -e "${RED}Failed to copy key. Check credentials and server availability.${NC}"
        echo -e "${YELLOW}Your public key (add it manually to ~/.ssh/authorized_keys on the server):${NC}"
        echo -e "${CYAN}$(cat "${KEY_PATH}.pub")${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Public key installed on server.${NC}"

# ------------------------------------------------------------------------------
# 4. Update Local SSH Config
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}[3/4] Updating ~/.ssh/config...${NC}"
CONFIG_FILE="$HOME/.ssh/config"
touch "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"

# Backup config before modification
BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
echo -e "${CYAN}Config backed up to: ${BACKUP_FILE}${NC}"

# Check for duplicate: look for a Host line that is exactly the alias
if awk '/^Host[[:space:]]/{found=0} /^Host[[:space:]]'"${HOST_ALIAS}"'[[:space:]]*$/{found=1} found' "$CONFIG_FILE" | grep -q .; then
    echo -e "${YELLOW}Entry for '${HOST_ALIAS}' already exists in config. Skipping append.${NC}"
else
    {
        echo ""
        echo "Host ${HOST_ALIAS}"
        echo "    HostName ${SERVER_IP}"
        echo "    Port ${SSH_PORT}"
        echo "    User ${SSH_USER}"
        echo "    IdentityFile ${KEY_PATH}"
        echo "    IdentitiesOnly yes"
        echo "    ServerAliveInterval 60"
        echo "    ServerAliveCountMax 3"
    } >> "$CONFIG_FILE"
    echo -e "${GREEN}Config entry added.${NC}"
fi

# ------------------------------------------------------------------------------
# 5. Test Connection
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}[4/4] Testing connection...${NC}"
ssh -o BatchMode=yes -o ConnectTimeout=5 "$HOST_ALIAS" "echo 'Connection successful!'"

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}================================================${NC}"
    echo -e "${GREEN} Setup complete!${NC}"
    echo -e " Connect with: ${CYAN}ssh ${HOST_ALIAS}${NC}"
    echo -e "${GREEN}================================================${NC}"
else
    echo -e "\n${YELLOW}Warning: Connection test failed.${NC}"
    echo "Key is installed, but check server sshd config or firewall."
    echo -e "Your public key:\n${CYAN}$(cat "${KEY_PATH}.pub")${NC}"
fi
