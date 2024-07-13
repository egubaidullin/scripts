#!/bin/bash

# PHP-FPM Optimization Script

set -e

# Function to display usage
usage() {
    echo "Usage: sudo $0"
    echo "This script detects installed PHP versions, shows current and proposed settings, and allows you to choose which to optimize."
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   usage
   exit 1
fi

# Function to detect installed PHP versions
detect_php_versions() {
    ls /etc/php/ | grep -E '^[0-9]+\.[0-9]+$' || echo "No PHP versions detected"
}

# Detect installed PHP versions
mapfile -t PHP_VERSIONS < <(detect_php_versions)
if [ ${#PHP_VERSIONS[@]} -eq 0 ]; then
    echo "No PHP versions detected. Please install PHP-FPM first."
    exit 1
fi

# Function to create a backup with timestamp
create_backup() {
    local file=$1
    local backup_dir="/root/php_backups"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/$(basename "$file").$(date +%Y%m%d%H%M%S).bak"
    cp "$file" "$backup_file"
    echo "Backup created: $backup_file"
}

# Function to get current value of a parameter
get_current_value() {
    local file=$1
    local param=$2
    grep -E "^$param\s*=" "$file" | cut -d'=' -f2- | tr -d '[:space:]' || echo "Not set"
}

# Function to update configuration file
update_config() {
    local file=$1
    local param=$2
    local value=$3
    local current_value

    current_value=$(get_current_value "$file" "$param")
    if [ "$current_value" != "$value" ]; then
        # Use ';' for commenting in PHP-FPM configuration files
        sed -i "s/^$param\s*=.*$/;& ; Old value\n$param = $value ; New value/" "$file"
        echo "Updated $param: $current_value -> $value"
    else
        echo "$param is already set to $value"
    fi
}

# Function to calculate system resources and PHP-FPM settings
calculate_system_resources() {
    total_ram=$(free -m | awk '/Mem/{print $2}')
    cpu_cores=$(nproc)
    
    # Calculate average PHP-FPM process size, use a default if no processes are running
    avg_process_size=$(ps -C php-fpm --no-headers -o rss | awk '{ sum += $1; count++ } END { if (count > 0) print int(sum / count / 1024); else print "0" }')
    
    if [ "$avg_process_size" == "0" ]; then
        echo "No PHP-FPM processes are currently running. Using default values for calculations."
        avg_process_size=50  # Default value in MB if no processes are running
    fi

    # Calculate recommended settings
    max_children=$((total_ram / avg_process_size))
    start_servers=$((cpu_cores * 2))
    min_spare_servers=$cpu_cores
    max_spare_servers=$((cpu_cores * 3))
    recommended_memory_limit="256M"

    echo "System information:"
    echo "Total RAM: $total_ram MB"
    echo "CPU cores: $cpu_cores"
    echo "Average PHP-FPM process size: $avg_process_size MB"
    echo
    echo "Recommended settings:"
    echo "pm.max_children = $max_children"
    echo "pm.start_servers = $start_servers"
    echo "pm.min_spare_servers = $min_spare_servers"
    echo "pm.max_spare_servers = $max_spare_servers"
    echo "memory_limit = $recommended_memory_limit"
    echo
}

# Function to get PHP-FPM settings
get_php_fpm_settings() {
    local php_version=$1
    local pool_conf="/etc/php/$php_version/fpm/pool.d/www.conf"
    local php_ini="/etc/php/$php_version/fpm/php.ini"

    echo "PHP $php_version settings:"
    echo "Current pm.max_children = $(get_current_value "$pool_conf" "pm.max_children") | Recommended = $max_children"
    echo "Current pm.start_servers = $(get_current_value "$pool_conf" "pm.start_servers") | Recommended = $start_servers"
    echo "Current pm.min_spare_servers = $(get_current_value "$pool_conf" "pm.min_spare_servers") | Recommended = $min_spare_servers"
    echo "Current pm.max_spare_servers = $(get_current_value "$pool_conf" "pm.max_spare_servers") | Recommended = $max_spare_servers"
    echo "Current memory_limit = $(get_current_value "$php_ini" "memory_limit") | Recommended = $recommended_memory_limit"
    echo
}

# Function to optimize a single PHP version
optimize_php_version() {
    local php_version=$1

    echo "Optimizing PHP $php_version"

    # Define file paths
    pool_conf="/etc/php/$php_version/fpm/pool.d/www.conf"
    php_ini="/etc/php/$php_version/fpm/php.ini"

    # Create backups
    create_backup "$pool_conf"
    create_backup "$php_ini"

    # Update pool configuration
    update_config "$pool_conf" "pm.max_children" "$max_children"
    update_config "$pool_conf" "pm.start_servers" "$start_servers"
    update_config "$pool_conf" "pm.min_spare_servers" "$min_spare_servers"
    update_config "$pool_conf" "pm.max_spare_servers" "$max_spare_servers"

    # Update PHP memory limit
    update_config "$php_ini" "memory_limit" "$recommended_memory_limit"

    # Restart PHP-FPM
    if systemctl restart "php$php_version-fpm"; then
        echo "PHP-FPM $php_version restarted successfully"
    else
        echo "Failed to restart PHP-FPM $php_version. Please check the service status manually."
    fi

    echo "Optimization for PHP $php_version completed"
    echo
}

# Main script logic
echo "Detected PHP versions: ${PHP_VERSIONS[*]}"
echo

# Calculate system resources and recommended settings
calculate_system_resources

# Display current settings and recommended changes for all versions
for version in "${PHP_VERSIONS[@]}"; do
    get_php_fpm_settings "$version"
done

echo "Select PHP versions to optimize:"
echo "0) All versions"
for i in "${!PHP_VERSIONS[@]}"; do
    echo "$((i+1))) ${PHP_VERSIONS[i]}"
done

read -p "Enter your choice (comma-separated numbers, e.g., 1,2 or 0 for all): " choice

if [[ $choice == "0" ]]; then
    selected_versions=("${PHP_VERSIONS[@]}")
else
    IFS=',' read -ra selected_indices <<< "$choice"
    selected_versions=()
    for index in "${selected_indices[@]}"; do
        if [[ $index -le ${#PHP_VERSIONS[@]} && $index -gt 0 ]]; then
            selected_versions+=("${PHP_VERSIONS[$((index-1))]}")
        fi
    done
fi

if [ ${#selected_versions[@]} -eq 0 ]; then
    echo "No valid PHP versions selected. Exiting."
    exit 1
fi

echo "You've selected to optimize the following PHP versions: ${selected_versions[*]}"
read -p "Do you want to proceed with the optimization? (y/n) " confirm

if [[ $confirm != [yY] ]]; then
    echo "Optimization cancelled."
    exit 0
fi

for version in "${selected_versions[@]}"; do
    optimize_php_version "$version"
done

echo "PHP-FPM optimization process completed for selected versions"
