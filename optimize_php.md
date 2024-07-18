# PHP-FPM Optimization Script

This Bash script is designed to optimize PHP-FPM settings based on your system resources. It detects installed PHP versions, displays current and proposed settings, and allows you to choose which versions to optimize.

## Requirements
- Root access
- Installed PHP-FPM versions

## Features

- Detects installed PHP-FPM versions
- Calculates system resources (total RAM, CPU cores, average PHP-FPM process size)
- Calculates recommended PHP-FPM settings (pm.max_children, pm.start_servers, pm.min_spare_servers, pm.max_spare_servers, memory_limit)
- Displays current and recommended settings for each detected PHP version
- Allows you to choose which PHP versions to optimize
- Creates backups of configuration files before making changes
- Restarts PHP-FPM services after optimization

## Usage

To use this script, simply execute it from the command line:
```bash
wget https://raw.githubusercontent.com/egubaidullin/scripts/main/optimize_php.sh && bash optimize_php.sh
```
or
```bash
wget https://raw.githubusercontent.com/egubaidullin/scripts/main/optimize_php.sh 
chmod +x optimize_php.sh
./optimize_php.sh
```

## Script Overview
1. Check if the script is run as root.
2. Detect installed PHP versions.
3. Calculate system resources and recommended settings.
4. Display current settings and recommended changes for all versions.
5. Prompt the user to select PHP versions to optimize.
6. Optimize the selected PHP versions:
   - Create backups of configuration files.
   - Update pool configuration and PHP memory limit.
   - Restart PHP-FPM service.
7. Confirm the completion of the optimization process.
