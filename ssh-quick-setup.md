# SSH VPS Manager

> Interactive SSH key & config manager for macOS — generate Ed25519 keys, copy them to remote servers, and manage `~/.ssh/config` entries.

### Requirements

- **macOS** (uses `ssh-keygen`, `ssh-copy-id`, BSD `sed`)
- OpenSSH (pre-installed on macOS)

### Usage

```sh
./ssh-manager.sh           # interactive menu
./ssh-manager.sh add       # add a new host
./ssh-manager.sh list      # list configured hosts
./ssh-manager.sh remove    # remove a host
./ssh-manager.sh rename    # rename a host
./ssh-manager.sh edit      # edit host params
./ssh-manager.sh test      # test connection
```
