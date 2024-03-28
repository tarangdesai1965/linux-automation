#!/bin/bash

# Function to print section headers
print_section_header() {
    echo "======================================================================"
    echo "$1"
    echo "======================================================================"
}

# Function to print error messages
print_error() {
    echo "ERROR: $1" >&2
}

# Function to check if a package is installed
is_package_installed() {
    dpkg -s "$1" &> /dev/null
}

# Function to add user accounts with specified configurations
add_user_accounts() {
    local users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

    for user in "${users[@]}"; do
        if ! id "$user" &> /dev/null; then
            echo "Creating user: $user"
            useradd -m -s /bin/bash "$user" || {
                print_error "Failed to create user: $user"
                continue
            }
        fi

        echo "Setting up SSH keys for user: $user"
        mkdir -p "/home/$user/.ssh"
        cat >> "/home/$user/.ssh/authorized_keys" <<-EOF
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm
# Add RSA and ED25519 public keys for user $user here
EOF
        chown -R "$user:$user" "/home/$user/.ssh"
        chmod 700 "/home/$user/.ssh"
        chmod 600 "/home/$user/.ssh/authorized_keys"
    done

    # Grant sudo access to dennis
    usermod -aG sudo dennis
}

# Function to configure network interface
configure_network_interface() {
    local interface="ens192"  # Modify interface name if needed
    local ip_address="192.168.16.21"
    local netmask="24"
    local netplan_file="/etc/netplan/01-netcfg.yaml"

    print_section_header "Configuring network interface"

    if [ -f "$netplan_file" ]; then
        if grep -q "ens192" "$netplan_file"; then
            echo "Network interface $interface already configured."
        else
            echo "Adding configuration for $interface to $netplan_file"
            cat >> "$netplan_file" <<-EOF
            network:
              version: 2
              ethernets:
                $interface:
                  addresses: [$ip_address/$netmask]
EOF
            netplan apply || {
                print_error "Failed to apply netplan configuration."
                return 1
            }
            echo "Network interface $interface configured successfully."
        fi
    else
        print_error "Netplan configuration file $netplan_file not found."
        return 1
    fi
}

# Function to configure /etc/hosts file
configure_hosts_file() {
    local hosts_file="/etc/hosts"
    local hostname="server1"
    local ip_address="192.168.16.21"

    print_section_header "Configuring /etc/hosts file"

    if grep -q "$hostname" "$hosts_file"; then
        sed -i "/$hostname/c\\$ip_address\t$hostname" "$hosts_file" || {
            print_error "Failed to update /etc/hosts file."
            return 1
        }
        echo "/etc/hosts file updated successfully."
    else
        echo "$ip_address\t$hostname" >> "$hosts_file" || {
            print_error "Failed to update /etc/hosts file."
            return 1
        }
        echo "/etc/hosts file updated successfully."
    fi
}

# Function to install required software packages
install_packages() {
    print_section_header "Installing required software packages"

    # Install apache2 if not installed
    if ! is_package_installed "apache2"; then
        echo "Installing apache2..."
        apt update && apt install -y apache2 || {
            print_error "Failed to install apache2."
            return 1
        }
        echo "apache2 installed successfully."
    else
        echo "apache2 is already installed."
    fi

    # Install squid if not installed
    if ! is_package_installed "squid"; then
        echo "Installing squid..."
        apt update && apt install -y squid || {
            print_error "Failed to install squid."
            return 1
        }
        echo "squid installed successfully."
    else
        echo "squid is already installed."
    fi
}

# Function to configure firewall using ufw
configure_firewall() {
    print_section_header "Configuring firewall using ufw"

    # Reset ufw to default settings
    echo "Resetting ufw to default settings..."
    ufw --force reset

    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing

    # Allow SSH on management network (assuming mgmt network is ens192)
    ufw allow in on ens192 to any port 22

    # Allow HTTP on both interfaces
    ufw allow in on ens192 to any port 80
    ufw allow in on ens192 to any port 80

    # Allow squid proxy on both interfaces
    ufw allow in on ens192 to any port 3128
    ufw allow in on ens192 to any port 3128

    # Enable ufw
    echo "Enabling ufw..."
    ufw --force enable

    echo "Firewall configured successfully."
}

# Main function
main() {
    add_user_accounts || return 1
    configure_network_interface || return 1
    configure_hosts_file || return 1
    install_packages || return 1
    configure_firewall || return 1

    echo "All configurations applied successfully."
}

# Execute main function
main
