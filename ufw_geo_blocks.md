This versatile script, ufw_geo_block.sh, empowers you to manage firewall rules in a Unix-like environment using UFW (Uncomplicated Firewall) based on geographic IP addresses. Whether you need to block or allow traffic from specific countries, set up port ranges, or work with different protocols like TCP and UDP, this script has you covered.

## Usage:

Before utilizing the script, ensure UFW is properly installed and configured on your system.

### Adding a Rule Without Port:

If you wish to block or allow traffic based solely on IP addresses, without specifying a port, the syntax is:

```
./ufw_geo_block.sh -d|--deny|-a|--allow -c|--country COUNTRY_CODE
```
### Adding a Rule with Port Ranges and Protocols:

To define port ranges and protocols (TCP or UDP), use the format start_port:end_port/protocol:

```
./ufw_geo_block.sh -d|--deny|-a|--allow -p|--port PORT_RANGE -c|--country COUNTRY_CODE
```
### Deleting a Rule:

To delete a previously added rule, use the following syntax:

```
./ufw_geo_block.sh -D|--delete -p|--port PORT_RANGE -c|--country COUNTRY_CODE
```
## Example Usage:

### To deny incoming traffic from Germany (DE) on port 80 (HTTP):

```
./ufw_geo_block.sh -d -p 80 -c DE
```
### To allow incoming traffic from Canada (CA) on ports 443 to 500 using UDP:

```
./ufw_geo_block.sh -a -p 443:500/udp -c CA
```
### To delete previously added rules for France (FR) without specifying a port:

```
./ufw_geo_block.sh -D -c FR
```
## Important Notes:

- Superuser privileges (**`sudo`**) are required to interact with UFW.
- Ensure proper UFW configuration before using the script.
- Understand the implications of blocking or allowing traffic from specific countries.
- Adjust the script for non-Ubuntu environments if necessary.
- Test the script in a controlled environment before applying to production.

With the ability to handle port ranges, various protocols, and even actions without port specifics, this script grants you fine-grained control over your firewall rules. Modify as needed and proceed with confidence in your firewall management tasks.
