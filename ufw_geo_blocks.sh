#!/bin/bash

#set -x

# Function to add firewall rule
function add_ufw_rule() {

  local ip=$1
  local port=$2
  local rule=$3
  local protocol=$4

  # Check rule
  if [ "$rule" == "deny" ]; then

    # Add deny rule with protocol
    sudo ufw deny from "$ip" to any port "$port" proto "$protocol"

  elif [ "$rule" == "allow" ]; then

    # Add allow rule with protocol
    sudo ufw allow from "$ip" to any port "$port" proto "$protocol"

  elif [ "$rule" == "delete" ]; then
    # Delete IP rule
    sudo ufw delete deny from "$ip" to any port "$port" proto "$protocol"
    sudo ufw delete allow from "$ip" to any port "$port" proto "$protocol"
    
  else
    echo "Invalid rule: $rule"
    return 1
  fi

  return 0

}

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -d|--deny)
      rule="deny"
      shift
      ;;
    -a|--allow)
      rule="allow"
      shift
     ;;
    -D|--delete)
      rule="delete"
      shift
      ;;
    -p|--port)
      port="$2"
      shift
      shift
     ;;
    -c|--country)
      country_code="$2"
      shift 
      shift
      ;;
    *)
      echo "Unknown parameter $key"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [ -z "$rule" ]; then
  echo "Missing required rule"
  exit 1 
fi

if [ -z "$country_code" ]; then
  echo "Missing country code"
  exit 1
fi

# Determine protocol 
protocol="tcp"
if [[ $port =~ .*/udp$ ]]; then
  protocol="udp"
fi

# Parse port range 
if [[ $port =~ ^([0-9]+):([0-9]+)/(tcp|udp)$ ]]; then

  start_port=${BASH_REMATCH[1]}
  end_port=${BASH_REMATCH[2]}

  # Validate format
  if ! [[ $port =~ ^[0-9]+:[0-9]+/(tcp|udp)$ ]]; then
    echo "Invalid port format"
    exit 1
  fi

else
  # Single port
  start_port="$port"
  end_port="$port"
fi

# Add or delete firewall rules
while read ip; do
  if [ -z "$start_port" ]; then
    # No port specified, apply rules based on IP address
    if [ "$rule" == "delete" ]; then
      sudo ufw delete deny from "$ip"
      sudo ufw delete allow from "$ip"
    elif [ "$rule" == "deny" ]; then
      sudo ufw deny from "$ip"
    elif [ "$rule" == "allow" ]; then
      sudo ufw allow from "$ip"
    fi
  else
    # Port(s) specified, apply rules based on IP address and port
    for p in $(seq "$start_port" "$end_port"); do
      if [ "$rule" == "delete" ]; then
        sudo ufw delete deny from "$ip" to any port "$p" proto "$protocol"
        sudo ufw delete allow from "$ip" to any port "$p" proto "$protocol"
      elif [ "$rule" == "deny" ]; then
        sudo ufw deny from "$ip" to any port "$p" proto "$protocol"
      elif [ "$rule" == "allow" ]; then
        sudo ufw allow from "$ip" to any port "$p" proto "$protocol"
      fi
    done
  fi
done < "$ip_file"


# Generate IP file path 
ip_file="$country_code.zone"

# Download IP file
wget -O "$ip_file" "http://www.ipdeny.com/ipblocks/data/countries/$ip_file"

# Check if download failed
if [ ! -s "$ip_file" ]; then
  echo "Failed to download IP file"
  exit 1
fi

# Determine protocol
protocol="tcp"
if [[ $port =~ .*/udp$ ]]; then
  protocol="udp" 
fi

if [ -z "$port" ]; then
  # No port specified, just apply rules based on IP address
  start_port=""
  end_port=""
else
  # Parse port range
  if [[ $port =~ ^([0-9]+):([0-9]+)/(tcp|udp)$ ]]; then
    start_port=${BASH_REMATCH[1]}
    end_port=${BASH_REMATCH[2]}
    # Validate format
    if ! [[ $port =~ ^[0-9]+:[0-9]+/(tcp|udp)$ ]]; then
      echo "Invalid port format"
      exit 1
    fi
  else
    # Single port
    start_port="$port"
    end_port="$port"
  fi
fi

# Add or delete firewall rules
while read ip; do
  if [ -z "$start_port" ]; then
    # No port specified, apply rules based on IP address
    if [ "$rule" == "delete" ]; then
      sudo ufw delete deny from "$ip"
      sudo ufw delete allow from "$ip"
    elif [ "$rule" == "deny" ]; then
      sudo ufw deny from "$ip"
    elif [ "$rule" == "allow" ]; then
      sudo ufw allow from "$ip"
    fi
  else
    # Port(s) specified, apply rules based on IP address and port
    if [ -n "$start_port" ] && [ -n "$end_port" ]; then
      for p in $(seq "$start_port" "$end_port"); do
        if [ "$rule" == "delete" ]; then
          sudo ufw delete deny from "$ip" to any port "$p" proto "$protocol"
          sudo ufw delete allow from "$ip" to any port "$p" proto "$protocol"
        elif [ "$rule" == "deny" ]; then
          sudo ufw deny from "$ip" to any port "$p" proto "$protocol"
        elif [ "$rule" == "allow" ]; then
          sudo ufw allow from "$ip" to any port "$p" proto "$protocol"
        fi
      done
    fi
  fi
done < "$ip_file"


# Clean up temp files
rm "$ip_file" 

echo "Done!"
