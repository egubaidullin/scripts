#!/bin/bash

# Set variables
USER_NAME="ftpuser"
USER_HOME="/home/${USER_NAME}"
SHARED_GROUP="webdata"
SHARED_DIR="/storage/your_folder"
CHROOT_DIR="/chroot/${USER_NAME}"
UPLOAD_DIR="${CHROOT_DIR}/upload"

# Create user if doesn't exist
if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
    echo "Creating user ${USER_NAME}..."
    useradd -m "${USER_NAME}"
else
    echo "User ${USER_NAME} already exists."
fi

# Create shared group if doesn't exist
if ! getent group "${SHARED_GROUP}" >/dev/null 2>&1; then
    echo "Creating group ${SHARED_GROUP}..."
    groupadd "${SHARED_GROUP}"
else
    echo "Group ${SHARED_GROUP} already exists."
fi

# Add users to shared group
usermod -a -G "${SHARED_GROUP}" "${USER_NAME}"
usermod -a -G "${SHARED_GROUP}" www-data

# Setup shared directory permissions
if [ ! -d "${SHARED_DIR}" ]; then
    echo "Creating shared directory ${SHARED_DIR}..."
    mkdir -p "${SHARED_DIR}"
fi
chown -R :${SHARED_GROUP} "${SHARED_DIR}"
chmod -R 770 "${SHARED_DIR}"

# Restrict user access
usermod -d "${USER_HOME}" "${USER_NAME}"
echo "${USER_NAME}:x:$(id -u ${USER_NAME}):$(id -g ${USER_NAME})::/home/${USER_NAME}:/bin/false" >> /etc/passwd

# Configure SSH access
echo "Configuring SSH access for ${USER_NAME}..."
echo "
Match User ${USER_NAME}
    ForceCommand internal-sftp
    PasswordAuthentication yes
    ChrootDirectory ${CHROOT_DIR}
    AllowTcpForwarding no
    X11Forwarding no
" >> /etc/ssh/sshd_config

# Setup chroot environment
if [ ! -d "${CHROOT_DIR}" ]; then
    echo "Creating chroot environment ${CHROOT_DIR}..."
    mkdir -p "${UPLOAD_DIR}"

    # Unmount previous bind mount if it exists
    if mount | grep -q "${UPLOAD_DIR}"; then
        echo "Unmounting ${UPLOAD_DIR}..."
        umount "${UPLOAD_DIR}"
    fi

    mount --bind "${SHARED_DIR}" "${UPLOAD_DIR}"
    chown -R root:root "${CHROOT_DIR}"
    chmod -R 755 "${CHROOT_DIR}"
fi

# Restart SSH service
systemctl restart sshd
