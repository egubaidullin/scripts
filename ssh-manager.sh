#!/usr/bin/env bash
# =============================================================================
#  ssh-manager.sh — SSH Key & Config Manager for macOS
#  Commands: add | list | remove | rename | edit | test
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[+]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[x]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }
header()  { local t="$*"; echo -e "\n${BOLD}${CYAN}${t}${RESET}"; printf '%s\n' "$(printf '%*s' "${#t}" '' | tr ' ' '-')"; }

# ── Paths ────────────────────────────────────────────────────────────────────
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
AUTH_KEYS="$SSH_DIR/authorized_keys"
MAX_BACKUPS=5

# ── Cleanup tmp files on exit ────────────────────────────────────────────────
TMP_FILES=()
cleanup() {
    # Loop body must not return non-zero under `set -e`; the [ -n "" ] test
    # for the expanded empty element would otherwise kill the script.
    for f in "${TMP_FILES[@]:-}"; do
        if [ -n "$f" ] && [ -f "$f" ]; then
            rm -f "$f"
        fi
    done
    return 0
}
trap cleanup EXIT

mktmp() {
    local t
    t=$(mktemp)
    TMP_FILES+=("$t")
    echo "$t"
}

# ── Helpers ──────────────────────────────────────────────────────────────────

ensure_ssh_dir() {
    if [ ! -d "$SSH_DIR" ]; then
        info "Creating $SSH_DIR ..."
        mkdir -p "$SSH_DIR"
    fi
    chmod 700 "$SSH_DIR"
    touch "$SSH_CONFIG" "$AUTH_KEYS"
    chmod 600 "$SSH_CONFIG" "$AUTH_KEYS"
}

backup_config() {
    local ts; ts=$(date +%Y%m%d_%H%M%S)
    local bak="${SSH_CONFIG}.bak.${ts}"
    cp "$SSH_CONFIG" "$bak"
    success "Config backed up -> $bak"
    prune_backups
}

prune_backups() {
    local backups
    backups=$(ls -1t "${SSH_CONFIG}".bak.* 2>/dev/null || true)
    [ -z "$backups" ] && return
    echo "$backups" | tail -n +"$((MAX_BACKUPS + 1))" | while IFS= read -r old; do
        rm -f "$old"
    done
}

validate_name() {
    local name="$1"
    [[ -z "$name" ]] && die "Name cannot be empty."
    [[ "$name" == "*" ]] && die "Name '*' is reserved (matches the global Host block)."
    [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid name '$name'. Use only letters, digits, dots, dashes, underscores."
}

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] || die "Port must be numeric."
    (( port >= 1 && port <= 65535 )) || die "Port must be between 1 and 65535."
}

host_exists() {
    local name="$1"
    [[ "$name" == "*" ]] && return 1
    # -F = fixed string (avoid regex injection via '.' or '-' in name)
    grep -qF "Host ${name}" "$SSH_CONFIG" 2>/dev/null
}

remove_host_block() {
    local name="$1"
    local tmp; tmp=$(mktmp)
    awk -v host="$name" '
        /^Host[[:space:]]/ {
            if ($2 == host) { skip = 1; next }
            skip = 0
        }
        !skip { print }
    ' "$SSH_CONFIG" > "$tmp"
    mv "$tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
}

get_host_param() {
    local name="$1" param="$2"
    awk -v host="$name" -v key="$param" '
        /^Host[[:space:]]/ {
            found = ($2 == host) ? 1 : 0
            next
        }
        found {
            if (match($0, "^[[:space:]]*" key "[[:space:]]+")) {
                val = substr($0, RSTART + RLENGTH)
                sub(/[[:space:]]+$/, "", val)
                print val
                exit
            }
        }
    ' "$SSH_CONFIG"
}

ensure_trailing_newline() {
    if [ -s "$SSH_CONFIG" ] && [ -n "$(tail -c1 "$SSH_CONFIG")" ]; then
        echo >> "$SSH_CONFIG"
    fi
}

# ── COMMAND: add ─────────────────────────────────────────────────────────────
cmd_add() {
    header "Add New SSH Host"

    read -rp "  Key name      (e.g. thai-vpn01)        : " KEY_NAME
    validate_name "$KEY_NAME"

    read -rp "  Remote IP / hostname                    : " REMOTE_IP
    [[ -z "$REMOTE_IP" ]] && die "Remote IP/hostname cannot be empty."

    read -rp "  SSH Port       [22]                     : " SSH_PORT
    SSH_PORT="${SSH_PORT:-22}"
    validate_port "$SSH_PORT"

    read -rp "  Username       [root]                   : " USERNAME
    USERNAME="${USERNAME:-root}"

    read -rp "  Protect key with a passphrase? [y/N]    : " USE_PASSPHRASE
    local KEY_PASSPHRASE=""
    # Note: ${var,,} is bash 4+. macOS /bin/bash is 3.2.57 (per `man bash`).
    # Use tr for POSIX-compatible lowercase that works in bash 3.2, bash 4, zsh.
    local _use_pp
    _use_pp=$(printf '%s' "$USE_PASSPHRASE" | tr '[:upper:]' '[:lower:]')
    if [[ "$_use_pp" == "y" ]]; then
        read -rsp "  Enter passphrase                        : " KEY_PASSPHRASE; echo
    fi

    local KEY_PATH="$SSH_DIR/$KEY_NAME"
    local PUB_KEY_PATH="$KEY_PATH.pub"

    echo
    info "Parameters:"
    echo "    Key name  : $KEY_NAME"
    echo "    Remote IP : $REMOTE_IP"
    echo "    Port      : $SSH_PORT"
    echo "    User      : $USERNAME"
    echo "    Passphrase: $([ -n "$KEY_PASSPHRASE" ] && echo yes || echo no)"
    echo

    ensure_ssh_dir

    if [ -f "$KEY_PATH" ] && [ -f "$PUB_KEY_PATH" ]; then
        warn "Key pair already exists at $KEY_PATH - skipping generation."
    else
        info "Generating ed25519 key pair ..."
        if ! ssh-keygen -t ed25519 -f "$KEY_PATH" -N "$KEY_PASSPHRASE" -C "${KEY_NAME}" -q; then
            die "ssh-keygen failed. Aborting before touching config."
        fi
        success "Key generated: $KEY_PATH"
    fi

    info "Copying public key to ${USERNAME}@${REMOTE_IP}:${SSH_PORT} ..."
    if ssh-copy-id -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
                   -i "$PUB_KEY_PATH" -p "$SSH_PORT" "${USERNAME}@${REMOTE_IP}"; then
        success "Public key copied to remote server."
    else
        warn "ssh-copy-id failed. You may need to add the key manually."
        warn "Public key path: $PUB_KEY_PATH"
    fi

    if host_exists "$KEY_NAME"; then
        warn "Host '$KEY_NAME' already exists in $SSH_CONFIG."
        read -rp "  Overwrite existing block? [y/N] : " OVERWRITE
        local _ow
        _ow=$(printf '%s' "$OVERWRITE" | tr '[:upper:]' '[:lower:]')
        if [[ "$_ow" == "y" ]]; then
            backup_config
            remove_host_block "$KEY_NAME"
            info "Existing block removed."
        else
            warn "Skipping config update. Existing block kept."
            echo
            success "Done (key ready, config unchanged)."
            echo -e "  Connect with: ${BOLD}ssh $KEY_NAME${RESET}"
            return
        fi
    else
        backup_config
    fi

    info "Appending config block to $SSH_CONFIG ..."
    ensure_trailing_newline

    cat >> "$SSH_CONFIG" << EOF

Host ${KEY_NAME}
    HostName ${REMOTE_IP}
    Port ${SSH_PORT}
    User ${USERNAME}
    IdentityFile ~/.ssh/${KEY_NAME}
    IdentitiesOnly yes
EOF
    chmod 600 "$SSH_CONFIG"
    success "SSH config updated."

    echo
    success "Setup complete!"
    echo -e "  Connect with: ${BOLD}ssh ${KEY_NAME}${RESET}"
}

# ── COMMAND: list ────────────────────────────────────────────────────────────
cmd_list() {
    header "Configured SSH Hosts"
    ensure_ssh_dir

    if [ ! -s "$SSH_CONFIG" ]; then
        warn "SSH config is empty."
        return
    fi

    local count=0
    local host="" hostname="" port="" user="" keyfile=""

    print_entry() {
        [ -z "$host" ] && return
        [ "$host" == "*" ] && return
        printf "  ${BOLD}%-20s${RESET}  %s@%s:%s\n" "$host" "${user:-?}" "${hostname:-?}" "${port:-22}"
        [ -n "$keyfile" ] && printf "  %-20s  key: %s\n" "" "$keyfile"
        echo
        count=$((count + 1))
    }

    while IFS= read -r line || [ -n "$line" ]; do
        # strip leading whitespace
        local stripped="${line#"${line%%[![:space:]]*}"}"
        case "$stripped" in
            Host\ *|Host$'\t'*)
                print_entry
                host="${stripped#Host}"
                host="${host#"${host%%[![:space:]]*}"}"
                hostname=""; port=""; user=""; keyfile=""
                ;;
            HostName\ *|HostName$'\t'*)
                hostname="${stripped#HostName}"
                hostname="${hostname#"${hostname%%[![:space:]]*}"}"
                hostname="${hostname%"${hostname##*[![:space:]]}"}"
                ;;
            Port\ *|Port$'\t'*)
                port="${stripped#Port}"
                port="${port#"${port%%[![:space:]]*}"}"
                port="${port%"${port##*[![:space:]]}"}"
                ;;
            User\ *|User$'\t'*)
                user="${stripped#User}"
                user="${user#"${user%%[![:space:]]*}"}"
                user="${user%"${user##*[![:space:]]}"}"
                ;;
            IdentityFile\ *|IdentityFile$'\t'*)
                keyfile="${stripped#IdentityFile}"
                keyfile="${keyfile#"${keyfile%%[![:space:]]*}"}"
                keyfile="${keyfile%"${keyfile##*[![:space:]]}"}"
                ;;
        esac
    done < "$SSH_CONFIG"
    print_entry

    [ "$count" -eq 0 ] && warn "No manageable Host entries found." || info "Total: $count host(s)"
}

# ── COMMAND: remove ──────────────────────────────────────────────────────────
cmd_remove() {
    header "Remove SSH Host"
    ensure_ssh_dir
    cmd_list

    read -rp "  Host name to remove: " KEY_NAME
    validate_name "$KEY_NAME"

    if ! host_exists "$KEY_NAME"; then
        die "Host '$KEY_NAME' not found in $SSH_CONFIG."
    fi

    local KEY_PATH="$SSH_DIR/$KEY_NAME"

    echo
    warn "This will:"
    echo "  - Remove the Host block from $SSH_CONFIG"
    [ -f "$KEY_PATH" ]     && echo "  - Delete private key : $KEY_PATH"
    [ -f "$KEY_PATH.pub" ] && echo "  - Delete public key  : $KEY_PATH.pub"
    echo

    read -rp "  Confirm removal? [y/N] : " CONFIRM
    local _cf
    _cf=$(printf '%s' "$CONFIRM" | tr '[:upper:]' '[:lower:]')
    [[ "$_cf" != "y" ]] && { info "Aborted."; return; }

    backup_config
    remove_host_block "$KEY_NAME"
    success "Host block '$KEY_NAME' removed from config."

    if [ -f "$KEY_PATH" ]; then
        rm -f "$KEY_PATH"
        success "Deleted private key: $KEY_PATH"
    fi
    if [ -f "$KEY_PATH.pub" ]; then
        rm -f "$KEY_PATH.pub"
        success "Deleted public key: $KEY_PATH.pub"
    fi

    success "Host '$KEY_NAME' fully removed."
}

# ── COMMAND: rename ──────────────────────────────────────────────────────────
cmd_rename() {
    header "Rename SSH Host"
    ensure_ssh_dir
    cmd_list

    read -rp "  Current host name : " OLD_NAME
    validate_name "$OLD_NAME"
    host_exists "$OLD_NAME" || die "Host '$OLD_NAME' not found in $SSH_CONFIG."

    read -rp "  New host name     : " NEW_NAME
    validate_name "$NEW_NAME"
    host_exists "$NEW_NAME" && die "Host '$NEW_NAME' already exists. Choose a different name."

    local OLD_KEY="$SSH_DIR/$OLD_NAME"
    local NEW_KEY="$SSH_DIR/$NEW_NAME"

    backup_config

    if [ -f "$OLD_KEY" ]; then
        mv "$OLD_KEY" "$NEW_KEY"
        success "Renamed private key -> $NEW_KEY"
    fi
    if [ -f "$OLD_KEY.pub" ]; then
        mv "$OLD_KEY.pub" "$NEW_KEY.pub"
        success "Renamed public key  -> $NEW_KEY.pub"
    fi

    # Rewrite the Host line and the IdentityFile line for this block.
    # Escape BRE metacharacters in OLD_NAME so '.' doesn't act as a wildcard.
    # Note: BSD sed on macOS does not support \+ in BRE; use [[:space:]]*.
    local esc_old
    esc_old=$(printf '%s' "$OLD_NAME" | sed 's/[].[\*^$\/]/\\&/g')
    local tmp; tmp=$(mktmp)
    sed "s|^Host[[:space:]]*${esc_old}\$|Host ${NEW_NAME}|" "$SSH_CONFIG" \
        | sed "s|~/\.ssh/${esc_old}\$|~/.ssh/${NEW_NAME}|" \
        > "$tmp"
    mv "$tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"

    success "Host renamed: '$OLD_NAME' -> '$NEW_NAME'"
    echo -e "  Connect with: ${BOLD}ssh ${NEW_NAME}${RESET}"
}

# ── COMMAND: edit ────────────────────────────────────────────────────────────
cmd_edit() {
    header "Edit SSH Host"
    ensure_ssh_dir
    cmd_list

    read -rp "  Host name to edit : " KEY_NAME
    validate_name "$KEY_NAME"
    host_exists "$KEY_NAME" || die "Host '$KEY_NAME' not found in $SSH_CONFIG."

    local cur_hostname cur_port cur_user
    cur_hostname=$(get_host_param "$KEY_NAME" "HostName")
    cur_port=$(get_host_param "$KEY_NAME" "Port")
    cur_user=$(get_host_param "$KEY_NAME" "User")

    echo
    info "Current values (press Enter to keep):"
    read -rp "  HostName [$cur_hostname] : " NEW_HOSTNAME
    NEW_HOSTNAME="${NEW_HOSTNAME:-$cur_hostname}"

    read -rp "  Port     [$cur_port]     : " NEW_PORT
    NEW_PORT="${NEW_PORT:-$cur_port}"
    validate_port "$NEW_PORT"

    read -rp "  User     [$cur_user]     : " NEW_USER
    NEW_USER="${NEW_USER:-$cur_user}"

    backup_config

    local tmp; tmp=$(mktmp)
    awk -v host="$KEY_NAME" -v hn="$NEW_HOSTNAME" -v pt="$NEW_PORT" -v us="$NEW_USER" '
        /^Host[[:space:]]/ { inblock = ($2 == host) ? 1 : 0; print; next }
        inblock && /^[[:space:]]+HostName[[:space:]]/ { print "    HostName " hn; next }
        inblock && /^[[:space:]]+Port[[:space:]]/     { print "    Port " pt;     next }
        inblock && /^[[:space:]]+User[[:space:]]/     { print "    User " us;     next }
        { print }
    ' "$SSH_CONFIG" > "$tmp"
    mv "$tmp" "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"

    success "Host '$KEY_NAME' updated."
    echo -e "  Connect with: ${BOLD}ssh ${KEY_NAME}${RESET}"
}

# ── COMMAND: test ────────────────────────────────────────────────────────────
cmd_test() {
    header "Test SSH Connection"
    ensure_ssh_dir
    cmd_list

    read -rp "  Host name to test: " KEY_NAME
    validate_name "$KEY_NAME"
    host_exists "$KEY_NAME" || die "Host '$KEY_NAME' not found in $SSH_CONFIG."

    _run_test "$KEY_NAME"
}

_run_test() {
    local KEY_NAME="$1"
    info "Testing connection to '$KEY_NAME' ..."
    echo "  (running: ssh -o BatchMode=yes -o ConnectTimeout=8 $KEY_NAME 'echo OK')"
    echo

    if ssh -o BatchMode=yes -o ConnectTimeout=8 "$KEY_NAME" 'echo "  Remote shell responded: OK"' 2>/dev/null; then
        success "Connection to '$KEY_NAME' successful!"
    else
        local rc=$?
        warn "Connection test failed (exit code: $rc)."
        # Re-run without stderr suppression so the user can see the real reason.
        echo
        info "ssh output:"
        ssh -o BatchMode=yes -o ConnectTimeout=8 "$KEY_NAME" 'true' 2>&1 | sed 's/^/    /' || true
        local remote_host; remote_host=$(get_host_param "$KEY_NAME" "HostName")
        echo
        info "Troubleshooting tips:"
        echo "  - Check the remote server is reachable: ping ${remote_host:-<host>}"
        echo "  - Verify the key was copied: ssh-copy-id -i ~/.ssh/${KEY_NAME}.pub <user>@<ip>"
        echo "  - Run with verbose output: ssh -v $KEY_NAME"
    fi
}

# ── USAGE ────────────────────────────────────────────────────────────────────
usage() {
    echo
    echo -e "${BOLD}ssh-manager.sh${RESET} - SSH Key & Config Manager"
    echo
    echo "  Usage: $0 <command>"
    echo
    echo "  Commands:"
    echo -e "    ${CYAN}add${RESET}     Generate key, copy to server, update ~/.ssh/config"
    echo -e "    ${CYAN}list${RESET}    Show all configured SSH hosts"
    echo -e "    ${CYAN}remove${RESET}  Remove host: delete keys + config block"
    echo -e "    ${CYAN}rename${RESET}  Rename a host and its key files"
    echo -e "    ${CYAN}edit${RESET}    Change HostName/Port/User without touching keys"
    echo -e "    ${CYAN}test${RESET}    Test SSH connection to a host"
    echo
    echo "  Examples:"
    echo "    $0 add"
    echo "    $0 list"
    echo "    $0 test thai-vpn01"
    echo
}

# ── Interactive menu ─────────────────────────────────────────────────────────
interactive_menu() {
    echo -e "${BOLD}${CYAN}"
    echo "  +=======================================+"
    echo "  |     SSH Manager - choose action       |"
    echo "  +=======================================+"
    echo -e "${RESET}"
    echo "  1) add    - Add new SSH host"
    echo "  2) list   - List configured hosts"
    echo "  3) remove - Remove a host"
    echo "  4) rename - Rename a host"
    echo "  5) edit   - Edit host params"
    echo "  6) test   - Test a connection"
    echo "  q) Quit"
    echo
    read -rp "  Choice [1-6/q]: " CHOICE
    case "$CHOICE" in
        1|add)    cmd_add    ;;
        2|list)   cmd_list   ;;
        3|remove) cmd_remove ;;
        4|rename) cmd_rename ;;
        5|edit)   cmd_edit   ;;
        6|test)   cmd_test   ;;
        q|Q)      exit 0     ;;
        *)        error "Unknown choice: $CHOICE"; usage; exit 1 ;;
    esac
}

# ── Entry point ──────────────────────────────────────────────────────────────
main() {
    local CMD="${1:-}"

    case "$CMD" in
        add)    cmd_add    ;;
        list)   cmd_list   ;;
        remove) cmd_remove ;;
        rename) cmd_rename ;;
        edit)   cmd_edit   ;;
        test)
            if [ -n "${2:-}" ]; then
                ensure_ssh_dir
                validate_name "$2"
                host_exists "$2" || die "Host '$2' not found in $SSH_CONFIG."
                header "Test SSH Connection"
                _run_test "$2"
            else
                cmd_test
            fi
            ;;
        -h|--help|help) usage ;;
        "")              interactive_menu ;;
        *)               error "Unknown command: $CMD"; usage; exit 1 ;;
    esac
}

main "$@"
