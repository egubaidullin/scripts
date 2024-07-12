# This project contains various scripts that I use for different purposes.

| Script | Description |
| --- | --- |
| **[ufw_ssh_whitelist.sh](ufw_ssh_whitelist.sh)** | This Bash script manages UFW rules to allow SSH access only from specified IP ranges. It fetches the whitelist from a GitHub repository and applies the rules to the detected SSH port. [Learn more](ufw_ssh_whitelist.md). |
| **[ufw_geo_block.sh](ufw_geo_block.sh)** | This script allows you to block or unblock IP addresses of a specific country using UFW (Uncomplicated Firewall). [Learn more]("ufw_geo_block.md"). |
| **[ufw_geo_blocks.sh](ufw_geo_blocks.sh)** | The script simplifies firewall rule management by leveraging UFW, allowing users to block or allow traffic from specific countries based on geographic IP addresses, and it accommodates port ranges and protocols for added flexibility in network security. [Learn more](ufw_geo_blocks.md)|
| **[generate-ip-cert.sh](generate-ip-cert.sh)** | This script generates a self-signed SSL certificate for an IP address. [Learn more](generate-ip-cert.md).|
| **[docker_install.sh](docker_install.sh)** | This will install the latest versions of Docker and Docker-compose on your system. [Learn more](docker_install.md). |
| **[tlg_login_notify.sh](tlg_login_notify.sh)** | This is a bash script that sends a notification to your Telegram account whenever someone logs in to your server via SSH. [Learn more](tlg_login_notify.md). |
| **[create_databases.sh](create_databases.sh)** | This Bash script simplifies the process of creating MySQL databases and granting privileges to the webmaster user. It provides the following features. [Learn more](create_databases.md). |
| **[optimize_php.sh](optimize_php.sh)** | This Bash script optimizes PHP-FPM settings and modifies PHP memory limits based on system resources. [Learn more](optimize_php.md). |
| **[SFTP_Restricted_Directory_Access.sh](SFTP_Restricted_Directory_Access.sh)** | This Bash script sets up secure SFTP access with restricted directory permissions for the user. [Learn more](SFTP_Restricted_Directory_Access.md). |
| **[project2file.py](project2file.py)** | Project2File is a Python script for saving project structure and file contents to text files. [Learn more](project2file.md). |
