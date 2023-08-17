#!/bin/bash

# Function for running remote command by using ssh on the target machine  
ssh_connection() {
    ssh -o "StrictHostKeyChecking=no" remoteadmin@$1 "$2"
}

# Function to check command execution status
verify_command() {
    if [ $? -eq 0 ]; then
        echo "SUCCESS: $1"
    else
        echo "ERROR: $1"
        exit 1
    fi
}

# Server 1
SERVER1_IP="172.16.1.10"
SERVER1_LAN="192.168.1.3"

# Set the system name to loghost 
echo "Setting system name..."
ssh_connection "$SERVER1_IP" "sudo hostnamectl set-hostname loghost"
verify_command "Setting system name"

# Deleting any existing LAN IP address and adding a new LAN IP address
ssh_connection "$SERVER1_IP" "sudo ip addr del $SERVER1_LAN/24 dev eth0 || true"
ssh_connection "$SERVER1_IP" "sudo ip addr add $SERVER1_LAN/24 dev eth0"
verify_command "Updating LAN IP address"

# Updating /etc/hosts file to add a machine
ssh_connection "$SERVER1_IP" "echo 'SERVER1_LAN webhost' | sudo tee -a /etc/hosts"
verify_command "Updating /etc/hosts file"

# updating ufw rules 
ssh_connection "$SERVER1_IP" "sudo apt update -qq && sudo apt install -y ufw"
ssh_connection "$SERVER1_IP" "sudo ufw allow from 172.16.1.0/24 to any port 514/udp"
verify_command "Updating ufw rules"

#Updates rsyslog configuration to enable UDP listening and restarts the rsyslog service to apply changes
#Uncomments the configuration lines related to 'imudp' and 'UDPServerRun' in the /etc/rsyslog.conf file
ssh_connection "$SERVER1_IP" "sed -i '/imudp/s/^#//g' /etc/rsyslog.conf"
ssh_connection "$SERVER1_IP" "sed -i '/UDPServerRun/s/^#//g' /etc/rsyslog.conf"
ssh_connection "$SERVER1_IP" "sudo systemctl restart rsyslog"
verify_command "Updating rsyslog configuration"


  
# Server 2
SERVER2_IP="172.16.1.11"
SERVER2_LAN="192.168.1.4"

# Set the system name to webhost
echo "Setting system name..."
ssh_connection "$SERVER2_IP" "sudo hostnamectl set-hostname webhost"
verify_command "Setting system name"

# Deleting any existing LAN IP address and adding a new LAN IP address
ssh_connection "$SERVER2_IP" "sudo ip addr del $SERVER2_LAN/24 dev eth0 || true"
ssh_connection "$SERVER2_IP" "sudo ip addr add $SERVER2_LAN/24 dev eth0"
verify_command "Updating LAN IP address"

# Updating /etc/hosts file to add a machine
ssh_connection "$SERVER2_IP" "echo 'SERVER2_LAN loghost' | sudo tee -a /etc/hosts"
verify_command "Updating /etc/hosts file"

# updating ufw rules 
ssh_connection "$SERVER2_IP" "sudo apt update -qq && sudo apt install -y ufw"
ssh_connection "$SERVER2_IP" "sudo ufw allow 80/tcp"
verify_command "Updating ufw rules"

# First updating and then Installing Apache2
sudo apt update -qq && sudo apt install -y apache2"
verify_command "Installing Apache2"

# Configure rsyslog on webhost to send logs to loghost and restart rsyslog to apply changes 
ssh_connection "$SERVER2_IP" "echo '*.* @loghost' | sudo tee -a /etc/rsyslog.conf"
ssh_connection "$SERVER2_IP" "sudo systemctl restart rsyslog"
verify_command "Configuring rsyslog on webhost to send logs to loghost"

# Updates NMS Configuration
echo "$SERVER1_IP loghost" | sudo tee -a /etc/hosts
echo "$SERVER2_IP webhost" | sudo tee -a /etc/hosts


# verify if Apache page can be retrieved 
if curl -s "http://webhost" | grep -q "Apache2 Ubuntu Default Page"; then
    echo "Apache page retrieval was successful."
else
    echo "Apache page retrieval was not successfull."
fi


# verify the presence of logs from webhost 
if ssh remoteadmin@loghost grep -q webhost /var/log/syslog; then
    echo " Logs from webhost are successfully retrieved on loghost."
else
    echo "Logs from webhost cannot be retrieved."
fi
