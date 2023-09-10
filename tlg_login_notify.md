# Telegram Notify on SSH Login

This script will send a Telegram message to a specified chat ID whenever someone logs in via SSH. It will also enable the execution of the notify-on-ssh-login.sh script on every SSH login.

## Requirements
- A Telegram account and a bot token. You can create a bot using the [@BotFather] and get your chat ID using the [@userinfobot].
- The curl command-line tool for sending HTTP requests.
- The pam_exec module for executing the script on login.

## Installation
- Download tlg_login_notify.sh to your server.
- Edit the file tlg_login_notify.sh and replace the values of TELEGRAM_TOKEN and CHAT_ID with your own.
- Make the file executable with `chmod 755 tlg_login_notify.sh`.
- Run the script `telegram-notify-on-ssh-login.sh` or run with `sudo bash telegram-notify-on-ssh-login.sh`.

You can also create manually file `notify-on-ssh-login.sh` and paste the following code:

```
#!/usr/bin/env bash
TELEGRAM_TOKEN="YOUR_TELEGRAM_TOKEN"
CHAT_ID="YOUR_CHAT_ID"
URL="https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage"

if [ "$PAM_TYPE" != "open_session" ]
then
        exit 0
else
        curl -s -X POST $URL -d chat_id=$CHAT_ID -d text="$(echo -e "Time: $(date +'%d/%m/%Y %H:%M:%S') ($(date +'%Z %z'))\nHost: `hostname`\nUser: $PAM_USER\nHost: $PAM_RHOST")" -d disable_notification=true  > /dev/null 2>&1
        exit 0
fi

```
- Copy the file to /etc/ssh/ or any other location of your choice.
- Edit the file/etc/pam.d/sshd and add the following line at the end:

``` session    optional     pam_exec.so  /etc/ssh/notify-on-ssh-login.sh ```

Restart the ssh service with sudo service ssh restart.
## Usage
Now, whenever someone logs in to your server via SSH, you will receive a message like this on your Telegram:

```
Host: test_host
User: user
Host: 192.168.2.238
```
## Options

You can change the format of the message by editing the `text` parameter in the curl command in `/etc/ssh/notify-on-ssh-login.sh`. You can use any of the [PAM environment variables] or other commands to get more information.

You can also remove the option `-d disable_notification=true` from the curl command if you want to receive a sound notification for each message. This option will mute the notification sound.
