#!/bin/bash
# Validator Node User Data Script for DigitalOcean
# This script runs on first boot to set up the validator

echo "=== Starting Validator Setup ==="

echo "root:${root_password}" | chpasswd
    
# Enable password authentication
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Update system
apt-get update

# Install required packages
apt-get install -y \
    docker.io \
    docker-compose \
    jq \
    htop \
    vim \
    tmux \
    xfsprogs

# Enable and start Docker
systemctl enable docker
systemctl start docker
usermod -aG docker root

# Wait for block storage volume to be attached
echo "Waiting for block storage volume..."
sleep 10

mkdir -p /var/lib/rippled
# Set permissions
chown -R root:root /var/lib/rippled

# Create directories
mkdir -p /opt/xrpl/configs
mkdir -p /opt/xrpl/scripts
mkdir -p /var/log/rippled

# Download validator configuration
cat > /opt/xrpl/configs/rippled.cfg <<'RIPPLED_CFG'
# FOR TESTNET CONFIGURATION
[server]
port_rpc_admin_local
port_peer
port_ws_admin_local

[port_rpc_admin_local]
port = 6006
ip = 127.0.0.1
admin = 127.0.0.1
protocol = http

[port_peer]
port = 51235
ip = 0.0.0.0
protocol = peer

[port_ws_admin_local]
port = 6007
ip = 127.0.0.1
admin = 127.0.0.1
protocol = ws

[node_size]
small

[node_db]
type=NuDB
path=/var/lib/rippled/db/nudb
online_delete=512
advisory_delete=0

[database_path]
/var/lib/rippled/db

[debug_logfile]
/var/log/rippled/debug.log

[sntp_servers]
time.google.com
time.cloudflare.com
pool.ntp.org

[validators_file]
validators.txt

[rpc_startup]
{ "command": "log_level", "severity": "warning" }

[ssl_verify]
0

[peer_private]
0

[transaction_queue]
minimum_txn_in_ledger_standalone = 1
minimum_last_ledger_buffer = 2
zero_basefee_transaction_feelevel = 256000
open_ledger_cost_trigger = 15

[network_id]
testnet

[ips]
# Devnet/Testnet bootstrap nodes
s.altnet.rippletest.net:51235
RIPPLED_CFG

# Create validators.txt
cat > /opt/xrpl/configs/validators.txt <<'VALIDATORS'
# FOR TESTNET CONFIGURATION
[validator_list_sites]
https://vl.altnet.rippletest.net

[validator_list_keys]
ED264807102805220DA0F312E71FC2C69E1552C9C5790F6C25E3729DEB573D5860
VALIDATORS

# Create docker-compose file
cat > /opt/xrpl/docker-compose.yml <<'DOCKER_COMPOSE'
version: "3.8"

services:
  rippled:
    image: xrpllabsofficial/xrpld:latest
    container_name: rippled
    restart: unless-stopped
    ports:
      - "51235:51235"
      - "127.0.0.1:6006:6006"
      - "127.0.0.1:6007:6007"
    volumes:
      - /var/lib/rippled:/var/lib/rippled
      - /opt/xrpl/configs:/etc/opt/ripple
      - /var/log/rippled:/var/log/rippled
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
DOCKER_COMPOSE

echo "=== Validator Setup Complete ==="
echo "To start the validator, run: cd /opt/xrpl && docker-compose up -d"

# Run docker-compose
cd /opt/xrpl && docker-compose up -d