# SFTP User Setup with Restricted Directory Access
## Script Description
This Bash script is designed to set up a secure file transfer environment for the `ftpuser` user. It facilitates the uploading of video files to a shared directory, which can then be served by an Nginx web server. The script performs several key functions:

- **User and Group Management**: It ensures that the `ftpuser` user and the `webdata` group exist on the system. If they don't, the script creates them.
- **Directory Setup**: It creates a shared directory at `/storage/your_folder` with appropriate permissions for the `webdata` group.
- **Access Restrictions**: It restricts the `ftpuser` user's access to their home directory and sets up a chroot environment to prevent access to the rest of the filesystem.
- **SFTP Configuration**: It configures SSH to use internal-sftp for the `ftpuser` user, allowing for secure file transfers.
- **Service Management**: It restarts the SSH service to apply the new configuration.

## Initial Setup
The script is pre-configured for the task of uploading video files for distribution via Nginx, using the `webdata` group to manage access permissions.

## How It Works
1. **User and Group Checks**: The script checks for the existence of the `ftpuser` user and the `webdata` group, creating them if necessary.
2. **Shared Directory**: It sets up a shared directory with the correct group ownership and permissions.
3. **User Restrictions**: The script modifies the user's home directory and adds an entry to `/etc/passwd` to restrict their access.
4. **SSH Configuration**: It appends configuration settings to `/etc/ssh/sshd_config` to set up a chroot environment and enable SFTP access.
5. **Chroot Environment**: The script creates the chroot directory and mounts the shared directory within it.
6. **Service Restart**: Finally, it restarts the SSH service to ensure the changes take effect.

## Configuration Steps
To configure the script for your environment, follow these steps:
1. **Set Variables**: Modify the `user`, `USER_HOME`, `SHARED_GROUP`, `SHARED_DIR`, `CHROOT_DIR`, and `UPLOAD_DIR` variables as needed.
2. **Run the Script**: Execute the script with root privileges.
3. **Verify Configuration**: Check the `/etc/ssh/sshd_config` file and the directory structure to ensure everything is set up correctly.
4. **Test SFTP Access**: Attempt to connect via SFTP with the `ftpuser` user to confirm that the setup is working.

## Recommendations
- **Backup**: Before running the script, ensure you have backups of important configuration files like `/etc/ssh/sshd_config`.
- **Testing**: Test the script in a controlled environment before deploying it to production.
- **Monitoring**: Set up monitoring for the SFTP service to track usage and detect potential issues.

This script streamlines the process of setting up a secure environment for media content uploads, making it easier to manage and distribute content through Nginx.
