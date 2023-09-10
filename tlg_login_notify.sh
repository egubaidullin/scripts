#!/bin/bash

# Check if the file /etc/ssh/notify-on-ssh-login.sh exists
if [ -f /etc/ssh/notify-on-ssh-login.sh ]; then
    # If the file exists, print a warning
    echo "The file /etc/ssh/notify-on-ssh-login.sh already exists!"
else
    # If the file does not exist, create it with the given content
    cat > /etc/ssh/notify-on-ssh-login.sh << EOF
TELEGRAM_TOKEN="YourTelegramToken"
CHAT_ID="YourChatID"
URL="https://api.telegram.org/bot\$TELEGRAM_TOKEN/sendMessage"

if [ "\$PAM_TYPE" != "open_session" ]
then
	exit 0
else
	curl -s -X POST \$URL -d chat_id=\$CHAT_ID -d text="\$(echo -e "Host: \`hostname\`\nUser: \$PAM_USER\nHost: \$PAM_RHOST")" > /dev/null 2>&1
	exit 0
fi
EOF
    # Make the file executable with permissions -rwxr-xr-x
    chmod 755 /etc/ssh/notify-on-ssh-login.sh
fi

# Check if the line "session    optional     pam_exec.so  /usr/local/bin/notify-on-ssh-login.sh" is in the file /etc/pam.d/sshd
if grep -q "session    optional     pam_exec.so  /usr/local/bin/notify-on-ssh-login.sh" /etc/pam.d/sshd; then
    # If the line is there, print a message
    echo "The line is already present in the file /etc/pam.d/sshd!"
else
    # If the line is not there, append it to the end of the file
    echo "session    optional     pam_exec.so  /usr/local/bin/notify-on-ssh-login.sh" >> /etc/pam.d/sshd
fi

# Finish the script
exit 0
