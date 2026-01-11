#!/bin/bash
set -e

# Validator Node User Data Script
# This script runs on first boot to set up the validator

echo "=== Starting Validator Setup ==="

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    docker.io \
    docker-compose \
    awscli \
    jq \
    htop \
    vim \
    tmux \
    nvme-cli \
    xfsprogs

# Enable and start Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Wait for EBS volume to be attached
echo "Waiting for EBS volume..."
while [ ! -e /dev/nvme1n1 ] && [ ! -e /dev/xvdf ]; do
    sleep 5
done

# Determine device name (EBS volumes can appear as nvme or xvdf)
if [ -e /dev/nvme1n1 ]; then
    DEVICE=/dev/nvme1n1
else
    DEVICE=/dev/xvdf
fi

echo "Found device: $DEVICE"

# Format and mount ledger volume if not already formatted
if ! blkid $DEVICE; then
    echo "Formatting ledger volume..."
    mkfs.xfs $DEVICE
fi

# Create mount point and mount
mkdir -p /var/lib/rippled
mount $DEVICE /var/lib/rippled

# Add to fstab for persistence
echo "$DEVICE /var/lib/rippled xfs defaults,nofail 0 2" >> /etc/fstab

# Set permissions
chown -R ubuntu:ubuntu /var/lib/rippled

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
time.aws.com
time.cloudflare.com

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

# Create health check script
cat > /opt/xrpl/scripts/health-check.sh <<'HEALTH_SCRIPT'
#!/bin/bash

# XRPL Validator Health Check Script

check_server_info() {
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"method": "server_info", "params": [{}]}' \
        http://127.0.0.1:6006/)
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq -r '.result.info.server_state'
    else
        echo "error"
    fi
}

check_peers() {
    response=$(curl -s -X POST -H "Content-Type: application/json" \
        -d '{"method": "peers", "params": [{}]}' \
        http://127.0.0.1:6006/)
    
    if [ $? -eq 0 ]; then
        echo "$response" | jq -r '.result.peers | length'
    else
        echo "0"
    fi
}

# Main health check
server_state=$(check_server_info)
peer_count=$(check_peers)

echo "Server State: $server_state"
echo "Peer Count: $peer_count"

# Exit with error if not healthy
if [[ "$server_state" != "full" && "$server_state" != "proposing" && "$server_state" != "validating" ]]; then
    echo "WARNING: Server not in healthy state"
    exit 1
fi

if [ "$peer_count" -lt 5 ]; then
    echo "WARNING: Low peer count"
    exit 1
fi

echo "Health check passed"
exit 0
HEALTH_SCRIPT

chmod +x /opt/xrpl/scripts/health-check.sh

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
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($|/)'

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - /var/log/rippled:/var/log/rippled:ro
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml
DOCKER_COMPOSE

# Create promtail configuration
cat > /opt/xrpl/promtail-config.yml <<'PROMTAIL'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://monitoring:3100/loki/api/v1/push

scrape_configs:
  - job_name: rippled
    static_configs:
      - targets:
          - localhost
        labels:
          job: rippled
          host: validator
          __path__: /var/log/rippled/*.log
    pipeline_stages:
      - regex:
          expression: '(?P<timestamp>\d{4}-\w{3}-\d{2} \d{2}:\d{2}:\d{2}\.\d+) (?P<level>\w+):(?P<component>\w+) (?P<message>.*)'
      - labels:
          level:
          component:
PROMTAIL

# Set ownership
chown -R ubuntu:ubuntu /opt/xrpl

echo "=== Validator Setup Complete ==="
echo "To start the validator, run: cd /opt/xrpl && docker-compose up -d"
