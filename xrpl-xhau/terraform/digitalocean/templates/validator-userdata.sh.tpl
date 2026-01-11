#!/bin/bash
set -e

# Validator Node User Data Script for DigitalOcean
# This script runs on first boot to set up the validator

echo "=== Starting Validator Setup ==="

# Update system
apt-get update
apt-get upgrade -y

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

# Find the attached volume (DigitalOcean volumes appear as /dev/disk/by-id/scsi-0DO_Volume_*)
VOLUME_PATH=$(ls /dev/disk/by-id/scsi-0DO_Volume_* 2>/dev/null | head -1)

if [ -n "$VOLUME_PATH" ]; then
    echo "Found volume: $VOLUME_PATH"
    
    # Create mount point
    mkdir -p /var/lib/rippled
    
    # Mount the volume (already formatted as XFS by DigitalOcean)
    mount -o defaults,nofail,discard,noatime "$VOLUME_PATH" /var/lib/rippled
    
    # Add to fstab for persistence
    echo "$VOLUME_PATH /var/lib/rippled xfs defaults,nofail,discard,noatime 0 2" >> /etc/fstab
else
    echo "No block storage volume found, using local storage"
    mkdir -p /var/lib/rippled
fi

# Set permissions
chown -R root:root /var/lib/rippled

# Create directories
mkdir -p /opt/xrpl/configs
mkdir -p /opt/xrpl/scripts
mkdir -p /var/log/rippled

# Download validator configuration
cat > /opt/xrpl/configs/rippled.cfg <<'RIPPLED_CFG'
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
medium

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
1

[peer_private]
0

[transaction_queue]
minimum_txn_in_ledger_standalone = 1
minimum_last_ledger_buffer = 2
zero_basefee_transaction_feelevel = 256000
open_ledger_cost_trigger = 15

# Network specific settings
%{ if network_type == "mainnet" ~}
[network_id]
0
[ips]
r.ripple.com 51235
zaphod.alloy.ee 51235
%{ endif ~}

%{ if network_type == "testnet" ~}
[network_id]
1
[ips]
s.altnet.rippletest.net 51235
%{ endif ~}

%{ if network_type == "devnet" ~}
[network_id]
2
[ips]
s.devnet.rippletest.net 51235
%{ endif ~}

%{ if network_type == "xahau" || network_type == "xahau-testnet" ~}
# Xahau specific configuration
[network_id]
21337

[features]
HooksV1

[amendments]
HooksV1 true
%{ endif ~}
RIPPLED_CFG

# Create validators.txt
cat > /opt/xrpl/configs/validators.txt <<'VALIDATORS'
[validator_list_sites]
https://vl.xrplf.org

[validator_list_keys]
ED2677ABFFD1B33AC6FBC3062B71F1E8397C1505E1C42C64D11AD1B28FF73F4734
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
      - /opt/xrpl/configs:/etc/rippled
      - /var/log/rippled:/var/log/rippled
    command: ["-a", "--conf", "/etc/rippled/rippled.cfg"]
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
