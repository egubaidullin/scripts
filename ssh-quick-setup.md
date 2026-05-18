# ssh-quick-setup

> One-shot script to connect a new remote VPS in under a minute.

Generates an `ed25519` key, installs it on the remote server, and writes a clean entry to `~/.ssh/config` — so you can just type `ssh my-vps` and you're in. Works on **macOS and Linux**.

---

## What it does

1. Generates an `ed25519` key named after your host alias (e.g. `~/.ssh/my-vps_ed25519`)
2. Copies the public key to the server (via `ssh-copy-id` on Linux, manual fallback on macOS)
3. Appends a config block to `~/.ssh/config`
4. Tests the connection

---

## Generated config entry

```
Host my-vps
    HostName 1.2.3.4
    Port 22
    User ubuntu
    IdentityFile ~/.ssh/my-vps_ed25519
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

`ServerAliveInterval` keeps idle VPS connections from dropping.

---

## Usage

```bash
chmod +x ssh-quick-setup.sh
./ssh-quick-setup.sh
```

The script will ask for:
- Host alias (used for the config entry and key filename)
- Server IP or hostname
- SSH port (default: 22)
- SSH username (default: root)

Then confirm and let it run. You'll need to enter the server **password once** to install the key.

---

## Requirements

- `ssh` and `ssh-keygen` (standard OpenSSH — pre-installed on macOS and most Linux distros)
- Password access to the remote server (just for the initial key install)

---

## Notes

- **No passphrase** on the generated key — intended for automation and scripted access
- `~/.ssh/config` is backed up before any modification (`config.bak.YYYYMMDD_HHMMSS`)
- If the host alias already exists in config, the script skips the append
- If `ssh-copy-id` is unavailable, falls back to a pure `ssh` pipe
