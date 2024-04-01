#!/bin/bash

# Determine if max_children reached  
sudo grep max_children /var/log/php7.4-fpm.log

# Get pm params
sudo grep -E "pm.max_children..." /etc/php/7.4/fpm/pool.d/www.conf

# Calculate RAM and max child size
total_ram=$(free -m | awk '/Mem/{print $2}')
max_child_size=$(ps aux | grep php-fpm | sort -k 6 -nr | awk 'BEGIN{sum=0;count=0} {sum+=$6; count++} END{print sum/count/1024}')

echo "Total RAM: $total_ram MB"
echo "Max child size: $max_child_size MB"

# Calculate ratio 
#ratio=$(bc <<< "scale=2; $total_ram/$max_child_size")
ratio=$(bc <<< "scale=0; $total_ram/$max_child_size")
#echo "Ratio: $ratio"

# Calculate cores
Cores=$(( $(lscpu | awk '/^Socket/{print $2}') * $(lscpu | awk '/^Core/{print $4}') ))
echo "Cores: $Cores"

# Recommended pm params
pm_min_spare_servers=$((2 * $Cores))
pm_start_servers=$((4 * $Cores)) 
pm_max_spare_servers=$((4 * $Cores))

echo "Recommended settings:"
echo "pm.min_spare_servers = $pm_min_spare_servers" 
echo "pm.start_servers = $pm_start_servers"
echo "pm.max_spare_servers = $pm_max_spare_servers"
echo "pm.max_children: $ratio"
echo "/etc/php/7.4/fpm/pool.d/www.conf"
