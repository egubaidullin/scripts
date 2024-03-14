#!/bin/bash

# Function to display usage
display_usage() {
    echo "Usage: $0 [-c <config_file>] <database1> [database2] [database3] ..."
    echo "Example: $0 -c config.ini mydb1 mydb2 mydb3"
    exit 1
}

# Read configuration file if provided
read_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        MYSQL_USER=$(grep -E ^MYSQL_USER= "$config_file" | cut -d'=' -f2)
        MYSQL_PASS=$(grep -E ^MYSQL_PASS= "$config_file" | cut -d'=' -f2)
    else
        MYSQL_USER="${MYSQL_USER:-root}"
        MYSQL_PASS="${MYSQL_PASS:-}"
    fi
}

# Create databases and grant privileges
create_databases() {
    for db in "$@"
    do
        echo "Creating database: $db"

        # Check if database already exists
        if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES LIKE '$db';" | grep -q "$db"; then
            echo "Database '$db' already exists. Skipping..."
            continue
        fi

        # Create database
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE DATABASE $db;"

        # Grant privileges to webmaster user
        read -p "Enter the desired privileges (comma-separated, or 'all' for all privileges): " privileges
        if [ "$privileges" == "all" ]; then
            privileges="ALL PRIVILEGES"
        fi
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT $privileges ON $db.* TO 'webmaster'@'localhost';"
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;"
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW GRANTS FOR 'webmaster'@'localhost';"
    done
}

# Parse command-line arguments
while getopts ":c:" opt; do
    case $opt in
        c)
            CONFIG_FILE="$OPTARG"
            ;;
        \?)
            display_usage
            ;;
    esac
done
shift $((OPTIND-1))

# Read configuration file and set defaults if not provided
read_config "${CONFIG_FILE:-config.ini}"

# Create the databases
create_databases "$@"
