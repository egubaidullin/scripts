#!/bin/bash

# Description
#
# ## PHP-FPM Optimization Script
#
# This Bash script optimizes PHP-FPM settings and modifies PHP memory limits based on system resources. It performs the following tasks:
#
# 1. Determines the current PHP version.
# 2. Checks the PHP-FPM log for maximum child process limit reached.
# 3. Retrieves the current `pm` and `memory_limit` settings.
# 4. Calculates the total system RAM, average PHP-FPM process size, and the recommended `pm.max_children` ratio.
# 5. Determines the number of CPU cores and calculates recommended values for `pm.min_spare_servers`, `pm.start_servers`, and `pm.max_spare_servers`.
# 6. Displays the recommended settings.
# 7. Creates a backup of the `php.ini` file in the user's home directory with a timestamp.
# 8. Prompts the user for confirmation before applying changes.
# 9. Updates the `pm` parameters and `memory_limit` in the `php.ini` file.
# 10. Verifies the applied changes and displays the updated settings.
# 11. Restarts PHP-FPM to apply the new settings.
#
# ### Usage
#
# ```
# bash /path/to/script.sh
# ```
#
# The script will guide you through the process and prompt for confirmation before making any changes.

# Display usage guide
echo "PHP-FPM Optimization Script"
echo "This script will optimize PHP-FPM settings and modify PHP memory limits based on system resources."
echo "It will create a backup of the php.ini file and prompt for confirmation before applying changes."
echo "Usage: bash $0"
echo ""

# Determine the current PHP version
php_version=$(php -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;")

# Function to update php.ini file
update_php_ini() {
    local php_ini_file="/etc/php/$php_version/fpm/php.ini"
    local backup_file="$HOME/php.ini.$(date +%Y%m%d%H%M%S).bak"
    local memory_limit="$1"

    # Create a backup of the php.ini file in the user's home directory with a timestamp
    sudo cp "$php_ini_file" "$backup_file"
    echo "Backup created: $backup_file"

    # Prompt for confirmation
    read -p "Apply recommended settings? (y/n) " confirm

    if [[ $confirm == "y" || $confirm == "Y" ]]; then
        # Apply recommended settings
        sudo sed -i "s/^pm.min_spare_servers=.*$/pm.min_spare_servers=$pm_min_spare_servers/g" "$php_ini_file"
        sudo sed -i "s/^pm.start_servers=.*$/pm.start_servers=$pm_start_servers/g" "$php_ini_file"
        sudo sed -i "s/^pm.max_spare_servers=.*$/pm.max_spare_servers=$pm_max_spare_servers/g" "$php_ini_file"
        sudo sed -i "s/^pm.max_children=.*$/pm.max_children=$ratio/g" "$php_ini_file"
        sudo sed -i "s/^memory_limit=.*$/memory_limit=$memory_limit/g" "$php_ini_file"

        # Verify changes
        echo "Updated settings:"
        echo "pm.min_spare_servers=$(sudo grep "^pm.min_spare_servers=" "$php_ini_file" | cut -d'=' -f2)"
        echo "pm.start_servers=$(sudo grep "^pm.start_servers=" "$php_ini_file" | cut -d'=' -f2)"
        echo "pm.max_spare_servers=$(sudo grep "^pm.max_spare_servers=" "$php_ini_file" | cut -d'=' -f2)"
        echo "pm.max_children=$(sudo grep "^pm.max_children=" "$php_ini_file" | cut -d'=' -f2)"
        echo "memory_limit=$(sudo grep "^memory_limit=" "$php_ini_file" | cut -d'=' -f2)"

        # Restart PHP-FPM
        sudo systemctl restart "php$php_version-fpm"
        echo "PHP-FPM restarted"
    else
        echo "No changes made"
    fi
}

# Check if maximum child processes limit reached
max_children_reached=$(sudo grep -c "max_children has been reached" "/var/log/php$php_version-fpm.log")

# Get current pm params
pm_params=$(sudo grep -E "^pm\.(min|max|start)_spare_servers" "/etc/php/$php_version/fpm/pool.d/www.conf")
echo "Current pm params: $pm_params"

# Get current memory_limit
memory_limit=$(php -r "echo ini_get('memory_limit');")
echo "Current memory_limit: $memory_limit"

# Calculate total RAM and max child process size
total_ram=$(free -m | awk '/Mem/{print $2}')
max_child_size=$(ps aux | grep "php-fpm: pool www" | sort -k 6 -nr | awk 'BEGIN{sum=0;count=0} {sum+=$6; count++} END{print sum/count/1024}')

echo "Total RAM: $total_ram MB"
echo "Max child size: $max_child_size MB"

# Calculate recommended pm.max_children ratio
ratio=$(( $total_ram / $max_child_size ))

# Calculate CPU cores
cores=$(( $(lscpu | awk '/^Socket/{print $2}') * $(lscpu | awk '/^Core/{print $4}') ))
echo "Cores: $cores"

# Recommended pm params
pm_min_spare_servers=$((2 * $cores))
pm_start_servers=$((4 * $cores))
pm_max_spare_servers=$((4 * $cores))

echo "Recommended settings:"
echo "pm.min_spare_servers=$pm_min_spare_servers"
echo "pm.start_servers=$pm_start_servers"
echo "pm.max_spare_servers=$pm_max_spare_servers"
echo "pm.max_children=$ratio"
recommended_memory_limit="512M"
echo "memory_limit=$recommended_memory_limit"

# Apply recommended settings
update_php_ini "$recommended_memory_limit"

echo "Done!"
