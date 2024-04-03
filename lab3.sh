#!/bin/bash
# lab3.sh

# Transfer configure-host.sh to server1-mgmt and execute
scp configure-host.sh remoteadmin@server1-mgmt:/root || { echo "Failed to transfer configure-host.sh to server1-mgmt."; exit 1; }
ssh remoteadmin@server1-mgmt -- /root/configure-host.sh -verbose -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4 || { echo "Failed to execute configure-host.sh on server1-mgmt."; exit 1; }

# Transfer configure-host.sh to server2-mgmt and execute
scp configure-host.sh remoteadmin@server2-mgmt:/root || { echo "Failed to transfer configure-host.sh to server2-mgmt."; exit 1; }
ssh remoteadmin@server2-mgmt -- /root/configure-host.sh -verbose -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3 || { echo "Failed to execute configure-host.sh on server2-mgmt."; exit 1; }

# Update localhost /etc/hosts
./configure-host.sh -verbose -hostentry loghost 192.168.16.3 || { echo "Failed to update localhost /etc/hosts for loghost."; exit 1; }
./configure-host.sh -verbose -hostentry webhost 192.168.16.4 || { echo "Failed to update localhost /etc/hosts for webhost."; exit 1; }
