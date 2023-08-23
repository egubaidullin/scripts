# UFW GEO blocker (Country IP Blocker)
## script: ufw_geo_block.sh
This script allows you to block or unblock IP addresses of a specific country using UFW (Uncomplicated Firewall).

## Usage
To use this script, you need to pass two parameters: deny or delete and a country code in ISO 3166-1 alpha-2 format.

For example, to block all IP addresses from ZIMBABWE (ZW), you can run:
```
./ufw_geo_block.sh deny zw
```

To unblock them, you can run:
```
./ufw_geo_block.sh delete zw
```
The script will download a file with IP addresses of the selected country from ipdeny.com and add or delete rules for UFW accordingly.

## Requirements
This script requires wget and ufw to be installed on your system.
