#!/bin/bash

# Create the directory if it doesn't exist
sudo mkdir -p /opt/scripts

# Create the script to clean the /var/mail directory
CLEAN_SCRIPT="/opt/scripts/clean_mail_dir.sh"

echo "#!/bin/bash

# Remove all files in the /var/mail directory
rm -rf /var/mail/*" | sudo tee $CLEAN_SCRIPT

# Make the script executable
sudo chmod +x $CLEAN_SCRIPT

# Set up the cron job to run the script daily
CRON_FILE="/etc/cron.d/clean_mail_dir"

echo "0 0 * * * root $CLEAN_SCRIPT" | sudo tee $CRON_FILE

# Ensure the cron job is run as root
sudo chmod 0644 $CRON_FILE

echo "Script to clean the /var/mail directory and cron job set up successfully."
