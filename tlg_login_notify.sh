#!/bin/bash

# Check if the file /etc/ssh/notify-on-ssh-login.sh exists
if [ ! -f /etc/ssh/notify-on-ssh-login.sh ]; then
    # Create the file with the given code and make it executable
    cat << EOF > /etc/ssh/notify-on-ssh-login.sh
#!/usr/bin/env bash

TELEGRAM_TOKEN="YOUR_TELEGRAM_TOKEN"
CHAT_ID="_YOUR_CHAT_ID"
URL="https://api.telegram.org/bot\$TELEGRAM_TOKEN/sendMessage"

if [ "\$PAM_TYPE" != "open_session" ]
then
        exit 0
else
        curl -s -X POST \$URL -d chat_id=\$CHAT_ID -d text="\$(echo -e "Time: \$(date +'%d/%m/%Y %H:%M:%S') (\$(date +'%Z %z'))\nHost: \`hostname\`\nUser: \$PAM_USER\nHost: \$PAM_RHOST")" -d disable_notification=true  > /dev/null 2>&1
        exit 0
fi
EOF

    chmod 755 /etc/ssh/notify-on-ssh-login.sh
    echo "File /etc/ssh/notify-on-ssh-login.sh created successfully."
else
    echo "Warning: File /etc/ssh/notify-on-ssh-login.sh already exists. Skipping creation."
fi

# Check if the file /etc/pam.d/sshd contains the line "session    optional     pam_exec.so  /etc/ssh/notify-on-ssh-login.sh"
if ! grep -q "session    optional     pam_exec.so  /etc/ssh/notify-on-ssh-login.sh" /etc/pam.d/sshd; then
    # Append the line to the end of the file
    echo "# Telegram notify on ssh login" >> /etc/pam.d/sshd
    echo "session    optional     pam_exec.so  /etc/ssh/notify-on-ssh-login.sh" >> /etc/pam.d/sshd
    echo "Line added to /etc/pam.d/sshd successfully."
else
    echo "Warning: Line already present in /etc/pam.d/sshd. Skipping addition."
fi
