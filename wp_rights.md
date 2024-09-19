# WordPress Permissions Script

This script sets the appropriate permissions and ownership for a WordPress installation running under Nginx on Ubuntu.

## Usage

1. Download and run the script using the following command:

    ```sh
    wget https://raw.githubusercontent.com/egubaidullin/scripts/main/wp_rights.sh && sudo bash wp_rights.sh /path/to/wordpress
    ```

    Replace `/path/to/wordpress` with the actual path to your WordPress installation directory.

2. The script will set the ownership to `www-data:www-data` and adjust the permissions for directories and files as follows:
    - Directories: `755`
    - Files: `644`
    - `wp-config.php`: `600`
    - `wp-content/uploads`, `wp-content/plugins`, and `wp-content/cache` directories: `755` for directories and `644` for files.

## Script Details

The script performs the following actions:

1. Changes the ownership of all files and directories in the specified WordPress directory to `www-data:www-data`.
2. Sets permissions to `755` for all directories.
3. Sets permissions to `644` for all files.
4. Sets permissions to `600` for the `wp-config.php` file.
5. Sets permissions to `755` for directories and `644` for files in the `wp-content/uploads`, `wp-content/plugins`, and `wp-content/cache` directories.
