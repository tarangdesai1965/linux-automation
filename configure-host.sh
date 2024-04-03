#!/bin/bash
# configure-host.sh

# Function to log changes
log_changes() {
    local message=$1
    if [ "$verbose" = true ]; then
        echo "$message"
    else
        logger -t configure-host.sh "$message"
    fi
}

# Function to update hostname
update_hostname() {
    local desired_name=$1
    if [ "$(hostname)" != "$desired_name" ]; then
        sudo hostnamectl set-hostname "$desired_name" || { echo "Failed to set hostname."; exit 1; }
        log_changes "Hostname updated to $desired_name"
    else
        log_changes "Hostname already set to $desired_name"
    fi
}

# Function to update IP address
update_ip_address() {
    local desired_ip=$1
    local lan_interface=$2
    if [ "$(ip -o -4 addr show $lan_interface | awk '{print $4}')" != "$desired_ip/24" ]; then
        sudo sed -i "s/address .*/address $desired_ip\/24/" /etc/netplan/*.yaml || { echo "Failed to update IP address."; exit 1; }
        sudo netplan apply || { echo "Failed to apply netplan configuration."; exit 1; }
        log_changes "IP address updated to $desired_ip on $lan_interface"
    else
        log_changes "IP address already set to $desired_ip on $lan_interface"
    fi
}

# Function to update /etc/hosts entry
update_hosts_entry() {
    local desired_name=$1
    local desired_ip=$2
    if ! grep -q "$desired_ip $desired_name" /etc/hosts; then
        sudo sed -i "/$desired_name/d" /etc/hosts || { echo "Failed to delete existing host entry."; exit 1; }
        echo "$desired_ip $desired_name" | sudo tee -a /etc/hosts > /dev/null || { echo "Failed to add new host entry."; exit 1; }
        log_changes "Added $desired_name with IP $desired_ip to /etc/hosts"
    else
        log_changes "Entry for $desired_name with IP $desired_ip already exists in /etc/hosts"
    fi
}

# Signal handling
trap '' SIGTERM SIGINT SIGHUP

# Default values
verbose=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -verbose)
            verbose=true
            shift
            ;;
        -name)
            desired_name="$2"
            shift 2
            ;;
        -ip)
            desired_ip="$2"
            shift 2
            ;;
        -hostentry)
            desired_name="$2"
            desired_ip="$3"
            shift 3
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Apply configurations
if [ -n "$desired_name" ]; then
    update_hostname "$desired_name"
fi

if [ -n "$desired_ip" ]; then
    update_ip_address "$desired_ip" "laninterface"
fi

if [ -n "$desired_name" ] && [ -n "$desired_ip" ]; then
    update_hosts_entry "$desired_name" "$desired_ip"
fi
