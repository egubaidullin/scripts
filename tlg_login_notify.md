# Telegram notify on ssh login
This is a simple bash script that sends a notification to your Telegram account whenever someone logs in to your server via SSH. It uses the Telegram API and the PAM module to send the message with the host name, user name and remote host of the login session.

## Requirements
A Telegram account and a bot token. You can create a bot using the [@BotFather] and get your chat ID using the [@userinfobot].
The curl command-line tool for sending HTTP requests.
The pam_exec module for executing the script on login.
## Installation
Download or clone this repository to your server.
Edit the file notify-on-ssh-login.sh and replace the values of TELEGRAM_TOKEN and CHAT_ID with your own.
Make the file executable with chmod 755 notify-on-ssh-login.sh.
Copy the file to /etc/ssh/ or any other location of your choice.
Edit the file/etc/pam.d/sshd and add the following line at the end:

``` session    optional     pam_exec.so  /etc/ssh/notify-on-ssh-login.sh ```

Restart the ssh service with sudo service ssh restart.
## Usage
Now, whenever someone logs in to your server via SSH, you will receive a message like this on your Telegram:

```
Host: test_host
User: user
Host: 192.168.2.238
```
