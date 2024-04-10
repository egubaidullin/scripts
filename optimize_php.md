# PHP-FPM Optimization Script

This Bash script is designed to optimize PHP-FPM settings and adjust the PHP memory limit based on available system resources. It automates the process of tuning PHP-FPM for optimal performance by analyzing your server's hardware specifications and current PHP configuration.

## Features

- Dynamically determines the current PHP version.
- Checks the PHP-FPM log for events where the maximum child process limit was reached.
- Retrieves the current `pm` parameters and `memory_limit` settings from the configuration.
- Calculates total system RAM and the average size of PHP-FPM child processes to recommend optimal `pm.max_children` settings.
- Determines the number of CPU cores to suggest values for `pm.min_spare_servers`, `pm.start_servers`, and `pm.max_spare_servers`.
- Displays recommended settings to the user.
- Creates a timestamped backup of the `php.ini` file in the user's home directory before applying any changes.
- Prompts the user for confirmation before modifying the `php.ini` file with recommended settings.
- Applies changes to the `pm` parameters and `memory_limit` setting in the `php.ini` file.
- Restarts PHP-FPM to apply new settings and displays the updated configuration for verification.

## Usage

To use this script, simply execute it from the command line:

```bash
bash /path/to/optimize_php.sh
