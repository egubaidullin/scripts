### setup_clean_mail_dir.sh Script Description

This script sets up a daily cron job to clean the `/var/mail` directory. It creates a cleaning script in `/opt/scripts` and configures a cron job to run this script every day at midnight.

### How to Download and Run the Script

1. **Using `curl`**:

```bash
curl -s https://raw.githubusercontent.com/egubaidullin/scripts/main/setup_clean_mail_dir.sh | sudo bash
```

2. **Using `wget`**:

```bash
wget -qO- https://raw.githubusercontent.com/egubaidullin/scripts/main/setup_clean_mail_dir.sh | sudo bash
```
