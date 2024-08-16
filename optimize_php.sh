#!/bin/bash

# Improved PHP-FPM Optimization Script with Error Handling and Logging

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
    echo "Usage: sudo $0 [--debug]"
    echo "This script detects installed PHP versions, shows current and proposed settings, and allows you to choose which to optimize."
    echo "Options:"
    echo "  --debug    Enable debug mode for verbose logging"
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   usage
   exit 1
fi

# Initialize debug mode flag
DEBUG=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) DEBUG=true ;;
        *) echo "Unknown parameter: $1"; usage; exit 1 ;;
    esac
    shift
done

# Function for debug logging
debug_log() {
    if $DEBUG; then
        echo "[DEBUG] $1" >&2
    fi
}

# Function to detect installed PHP versions
detect_php_versions() {
    debug_log "Detecting installed PHP versions"
    ls /etc/php/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+$' || echo "No PHP versions detected"
}

# Detect installed PHP versions
mapfile -t PHP_VERSIONS < <(detect_php_versions)
if [ ${#PHP_VERSIONS[@]} -eq 0 ]; then
    echo "No PHP versions detected. Please install PHP-FPM first."
    exit 1
fi

debug_log "Detected PHP versions: ${PHP_VERSIONS[*]}"

# Function to create a backup with timestamp
create_backup() {
    local file=$1
    local backup_dir="/root/php_backups"
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/$(basename "$file").$(date +%Y%m%d%H%M%S).bak"
    cp "$file" "$backup_file"
    echo "Backup created: $backup_file"
    debug_log "Created backup: $backup_file"
}

# Function to get current value of a parameter
get_current_value() {
    local file=$1
    local param=$2
    if [ ! -f "$file" ]; then
        echo "Configuration file not found: $file" >&2
        return 1
    fi
    grep -E "^$param\s*=" "$file" | cut -d'=' -f2- | tr -d '[:space:]' || echo "Not set"
}

# Function to update configuration file
update_config() {
    local file=$1
    local param=$2
    local value=$3
    local current_value

    if [ ! -f "$file" ]; then
        echo "Configuration file not found: $file" >&2
        return 1
    fi

    current_value=$(get_current_value "$file" "$param")
    if [ "$current_value" != "$value" ]; then
        sed -i "s/^$param\s*=.*$/$param = $value/" "$file"
        echo "Updated $param: $current_value -> $value"
        debug_log "Updated $param in $file: $current_value -> $value"
    else
        echo "$param is already set to $value"
        debug_log "$param is already set to $value in $file"
    fi
}

# Function to calculate system resources and PHP-FPM settings for a specific version
calculate_php_fpm_settings() {
    local php_version=$1
    local total_ram=$(free -m | awk '/Mem/{print $2}')
    local cpu_cores=$(nproc)

    debug_log "Calculating settings for PHP $php_version"
    debug_log "Total RAM: $total_ram MB, CPU cores: $cpu_cores"

    # Calculate average PHP-FPM process size for this specific version
    local avg_process_size=$(ps -C php-fpm$php_version --no-headers -o rss 2>/dev/null | awk '{ sum += $1; count++ } END { if (count > 0) print int(sum / count / 1024); else print "0" }')

    if [ "$avg_process_size" == "0" ]; then
        echo "Warning: No PHP-FPM $php_version processes are currently running. Using default values for calculations." >&2
        avg_process_size=50  # Default value in MB if no processes are running
    fi

    debug_log "Average PHP-FPM $php_version process size: $avg_process_size MB"

    # Calculate recommended settings
    local max_children=$((total_ram / avg_process_size))
    local start_servers=$((cpu_cores * 2))
    local min_spare_servers=$cpu_cores
    local max_spare_servers=$((cpu_cores * 3))
    local recommended_memory_limit="256M"

    debug_log "Calculated settings: max_children=$max_children, start_servers=$start_servers, min_spare_servers=$min_spare_servers, max_spare_servers=$max_spare_servers, memory_limit=$recommended_memory_limit"

    echo "$max_children $start_servers $min_spare_servers $max_spare_servers $recommended_memory_limit $avg_process_size"
}

# Function to get and display PHP-FPM settings
get_php_fpm_settings() {
    local php_version=$1
    local pool_conf="/etc/php/$php_version/fpm/pool.d/www.conf"
    local php_ini="/etc/php/$php_version/fpm/php.ini"

    debug_log "Getting settings for PHP $php_version"

    if [ ! -f "$pool_conf" ] || [ ! -f "$php_ini" ]; then
        echo "Error: Configuration files for PHP $php_version not found." >&2
        return 1
    fi

    # Get recommended settings
    read -r rec_max_children rec_start_servers rec_min_spare_servers rec_max_spare_servers rec_memory_limit avg_process_size <<< $(calculate_php_fpm_settings $php_version)

    echo "PHP $php_version settings:"
    echo "Average PHP-FPM process size: $avg_process_size MB"

    # Function for formatted output of settings
    print_setting() {
        local param=$1
        local current=$2
        local recommended=$3
        printf "%-25s = %-10s | Recommended = %-10s\n" "$param" "$current" "$recommended"
    }

    print_setting "pm.max_children" "$(get_current_value "$pool_conf" "pm.max_children")" "$rec_max_children"
    print_setting "pm.start_servers" "$(get_current_value "$pool_conf" "pm.start_servers")" "$rec_start_servers"
    print_setting "pm.min_spare_servers" "$(get_current_value "$pool_conf" "pm.min_spare_servers")" "$rec_min_spare_servers"
    print_setting "pm.max_spare_servers" "$(get_current_value "$pool_conf" "pm.max_spare_servers")" "$rec_max_spare_servers"
    print_setting "memory_limit" "$(get_current_value "$php_ini" "memory_limit")" "$rec_memory_limit"
    echo
}

# Function to optimize a single PHP version
optimize_php_version() {
    local php_version=$1

    echo "Optimizing PHP $php_version"
    debug_log "Starting optimization for PHP $php_version"

    # Define file paths
    local pool_conf="/etc/php/$php_version/fpm/pool.d/www.conf"
    local php_ini="/etc/php/$php_version/fpm/php.ini"

    if [ ! -f "$pool_conf" ] || [ ! -f "$php_ini" ]; then
        echo "Error: Configuration files for PHP $php_version not found." >&2
        return 1
    fi

    # Create backups
    create_backup "$pool_conf"
    create_backup "$php_ini"

    # Get recommended settings
    read -r max_children start_servers min_spare_servers max_spare_servers recommended_memory_limit avg_process_size <<< $(calculate_php_fpm_settings $php_version)

    # Update pool configuration
    update_config "$pool_conf" "pm.max_children" "$max_children"
    update_config "$pool_conf" "pm.start_servers" "$start_servers"
    update_config "$pool_conf" "pm.min_spare_servers" "$min_spare_servers"
    update_config "$pool_conf" "pm.max_spare_servers" "$max_spare_servers"

    # Update PHP memory limit
    update_config "$php_ini" "memory_limit" "$recommended_memory_limit"

    # Test configuration files
    if ! php-fpm$php_version -t; then
        echo "Error: Configuration files for PHP $php_version are invalid. Rolling back changes." >&2
        rollback_changes "$pool_conf" "$php_ini"
        return 1
    fi

    # Restart PHP-FPM
    if systemctl is-active --quiet "php$php_version-fpm"; then
        if systemctl restart "php$php_version-fpm"; then
            echo "PHP-FPM $php_version restarted successfully"
            debug_log "PHP-FPM $php_version restarted successfully"
        else
            echo "Failed to restart PHP-FPM $php_version. Rolling back changes." >&2
            rollback_changes "$pool_conf" "$php_ini"
            return 1
        fi
    else
        echo "PHP-FPM $php_version is not running. Skipping restart."
        debug_log "PHP-FPM $php_version is not running. Skipping restart."
    fi

    echo "Optimization for PHP $php_version completed"
    debug_log "Optimization for PHP $php_version completed"
    echo
}

# Function to roll back changes
rollback_changes() {
    local pool_conf=$1
    local php_ini=$2
    local backup_dir="/root/php_backups"

    echo "Rolling back changes for PHP $php_version"
    debug_log "Rolling back changes for PHP $php_version"

    # Restore backup files
    cp "$backup_dir/$(basename "$pool_conf")."*".bak" "$pool_conf"
    cp "$backup_dir/$(basename "$php_ini")."*".bak" "$php_ini"

    echo "Changes rolled back successfully"
    debug_log "Changes rolled back successfully"
}

# Function to validate PHP version selection
validate_php_version_selection() {
    local choice=$1
    local selected_versions=()

    if [[ $choice == "0" ]]; then
        selected_versions=("${PHP_VERSIONS[@]}")
    else
        IFS=',' read -ra selected_indices <<< "$choice"
        for index in "${selected_indices[@]}"; do
            if [[ $index =~ ^[0-9]+$ ]] && [[ $index -le ${#PHP_VERSIONS[@]} && $index -gt 0 ]]; then
                selected_versions+=("${PHP_VERSIONS[$((index-1))]}")
            else
                echo "Invalid PHP version selection: $index" >&2
                return 1
            fi
        done
    fi

    echo "${selected_versions[@]}"
}

# Main script logic
echo "Detected PHP versions: ${PHP_VERSIONS[*]}"
echo

echo "System information:"
echo "Total RAM: $(free -m | awk '/Mem/{print $2}') MB"
echo "CPU cores: $(nproc)"
echo

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

selected_versions=($(validate_php_version_selection "$choice"))
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
debug_log "Script execution completed"
