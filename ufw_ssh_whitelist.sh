#!/bin/bash

set -euo pipefail

# Default SSH port
DEFAULT_SSH_PORT=22

# Function to get the current SSH port
get_ssh_port() {
    local ssh_port

    if [[ -n "${SSH_PORT:-}" ]]; then
        ssh_port="$SSH_PORT"
    else
        # Look for an uncommented Port line in sshd_config
        ssh_port=$(grep "^Port [0-9]*$" /etc/ssh/sshd_config | awk '{print $2}' | tail -n1)
        
        # If no uncommented Port found, use the default
        ssh_port=${ssh_port:-$DEFAULT_SSH_PORT}
    fi

    echo "$ssh_port"
}

# Function to fetch the whitelist from GitHub
fetch_whitelist() {
    local whitelist_url="https://raw.githubusercontent.com/your_repo/your_file"
    local whitelist_file="/tmp/ssh_whitelist.txt"

    if ! curl -sSf "$whitelist_url" -o "$whitelist_file"; then
        echo "Error: Failed to fetch whitelist from GitHub" >&2
        exit 1
    fi

    echo "$whitelist_file"
}

# Function to apply UFW rules
apply_ufw_rules() {
    local ssh_port="$1"
    local whitelist_file="$2"

    # Ensure UFW is installed
    if ! command -v ufw >/dev/null 2>&1; then
        echo "Error: UFW is not installed. Please install it first." >&2
        exit 1
    fi

    # Disable UFW to prevent lockout
    sudo ufw disable

    # Reset UFW rules
    sudo ufw --force reset

    # Allow SSH from anywhere (temporary)
    sudo ufw allow "$ssh_port"/tcp

    # Apply whitelist rules
    while IFS= read -r ip_range; do
        [[ "$ip_range" =~ ^#.*$ || -z "$ip_range" ]] && continue
        sudo ufw allow from "$ip_range" to any port "$ssh_port" proto tcp
    done < "$whitelist_file"

    # Enable UFW
    sudo ufw --force enable

    # Remove the temporary full SSH access rule
    sudo ufw delete allow "$ssh_port"/tcp

    # Reload UFW
    sudo ufw reload
}

main() {
    local ssh_port
    local whitelist_file

    ssh_port=$(get_ssh_port)
    whitelist_file=$(fetch_whitelist)

    echo "Using SSH port: $ssh_port"

    apply_ufw_rules "$ssh_port" "$whitelist_file"

    echo "UFW rules have been updated successfully."
}

main
