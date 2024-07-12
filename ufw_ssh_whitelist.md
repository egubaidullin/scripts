# UFW SSH Whitelist Script

This script manages UFW (Uncomplicated Firewall) rules to allow SSH access only from specified IP ranges. It fetches the whitelist from a GitHub repository and applies the rules to the detected SSH port.

## Prerequisites

- Ubuntu or Debian-based system
- UFW installed
- `curl` installed
- Sudo privileges

## Usage
Edit the script to set your GitHub whitelist URL:
```bash
local whitelist_url="https://raw.githubusercontent.com/your_username/your_repo/main/whitelist.txt"
```

## Whitelist File Format
The whitelist file should contain one IP address or CIDR range per line. Comments (lines starting with #) and empty lines are ignored.

Example whitelist.txt:
```
# Company office
203.0.113.0/24

# Remote worker 1
198.51.100.17

# VPN server
192.0.2.128/25

# Cloud provider IP range
172.16.0.0/12
```
## Customization
To change the default SSH port, modify the DEFAULT_SSH_PORT variable in the script.
You can set the SSH_PORT environment variable to override the detected SSH port:
```bash
sudo SSH_PORT=2222 ./ufw_ssh_whitelist.sh
```

## Important Notes
This script will reset all existing UFW rules. Make sure you have a backup of your current rules if needed.
