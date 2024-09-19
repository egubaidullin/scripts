#!/bin/bash

# Check if the script received the WordPress directory as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <WORDPRESS_DIR>"
  exit 1
fi

WORDPRESS_DIR="$1"

# Change the ownership of the WordPress directory
sudo chown -R www-data:www-data $WORDPRESS_DIR

# Set permissions for directories
sudo find $WORDPRESS_DIR -type d -exec chmod 755 {} \;

# Set permissions for files
sudo find $WORDPRESS_DIR -type f -exec chmod 644 {} \;

# Set permissions for wp-config.php
sudo chmod 600 $WORDPRESS_DIR/wp-config.php

# Set permissions for the uploads directory
sudo find $WORDPRESS_DIR/wp-content/uploads -type d -exec chmod 755 {} \;
sudo find $WORDPRESS_DIR/wp-content/uploads -type f -exec chmod 644 {} \;

# Set permissions for the plugins directory
sudo find $WORDPRESS_DIR/wp-content/plugins -type d -exec chmod 755 {} \;
sudo find $WORDPRESS_DIR/wp-content/plugins -type f -exec chmod 644 {} \;

# Set permissions for the cache directory
sudo find $WORDPRESS_DIR/wp-content/cache -type d -exec chmod 755 {} \;
sudo find $WORDPRESS_DIR/wp-content/cache -type f -exec chmod 644 {} \;

echo "Permissions and ownership settings completed."
