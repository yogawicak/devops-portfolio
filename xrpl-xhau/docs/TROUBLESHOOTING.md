# XRPL/Xahau Validator Troubleshooting Guide

This guide covers common issues encountered when operating XRPL/Xahau validator nodes and their solutions.

## Table of Contents

1. [Quick Diagnostics](#quick-diagnostics)
2. [Validator Not Syncing](#validator-not-syncing)
3. [UNL and Quorum Issues](#unl-and-quorum-issues)
4. [Peer Connection Problems](#peer-connection-problems)
5. [Performance Issues](#performance-issues)
6. [Amendment Blocked](#amendment-blocked)
7. [Database Issues](#database-issues)
8. [Network Connectivity](#network-connectivity)
9. [Monitoring Alerts](#monitoring-alerts)

---

## Quick Diagnostics

### Check Server Status

```bash
# Basic server info
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"server_info","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result.info'

# Check server state
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"server_info","params":[{}]}' \
  http://127.0.0.1:6006/ | jq -r '.result.info.server_state'

# Run health check script
./scripts/health-check.sh
```

### Server State Reference

| State | Description | Action Required |
|-------|-------------|----------------|
| `disconnected` | Not connected to network | Check network connectivity |
| `connected` | Connected, starting sync | Wait for sync to complete |
| `syncing` | Downloading ledger history | Wait for sync to complete |
| `tracking` | Following network | May still be catching up |
| `full` | Fully synchronized | ✅ Healthy |
| `proposing` | Participating in consensus | ✅ Healthy (validator) |
| `validating` | Validating ledgers | ✅ Healthy (validator) |

---

## Validator Not Syncing

### Symptoms
- Server state stuck at `connected` or `syncing`
- Ledger sequence not advancing
- High ledger age (> 60 seconds)

### Diagnosis

```bash
# Check current ledger info
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"server_info","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result.info.validated_ledger'

# Check sync status
watch -n 5 'curl -s -X POST -H "Content-Type: application/json" \
  -d '\''{"method":"server_info","params":[{}]}'\'' \
  http://127.0.0.1:6006/ | jq -r ".result.info.validated_ledger.seq"'
```

### Solutions

#### 1. Check Peer Connections

```bash
# Get peer count
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"peers","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result.peers | length'
```

If peer count is low (< 5):
- Check firewall allows port 51235 (TCP/UDP)
- Verify security group rules
- Check if peers are configured correctly in `rippled.cfg`

#### 2. Clear Database and Re-sync

```bash
# Stop the validator
docker-compose down

# Backup existing data (optional)
mv /var/lib/rippled/db /var/lib/rippled/db.backup

# Restart
docker-compose up -d
```

#### 3. Check Disk Space

```bash
df -h /var/lib/rippled
```

If disk is > 90% full:
- Increase `online_delete` value in config
- Add more storage
- Clear old databases

#### 4. Check Time Synchronization

```bash
# Check NTP status
timedatectl status

# Force sync
sudo systemctl restart systemd-timesyncd
```

---

## UNL and Quorum Issues

### Symptoms
- Validator not participating in consensus
- "Quorum not met" in logs
- Low UNL validator count

### Diagnosis

```bash
# Check UNL status
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"validators","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result'

# Check validation quorum
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"server_info","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result.info.validation_quorum'
```

### Solutions

#### 1. Verify UNL Configuration

Check `validators.txt`:
```ini
[validator_list_sites]
https://vl.xrplf.org

[validator_list_keys]
ED2677ABFFD1B33AC6FBC3062B71F1E8397C1505E1C42C64D11AD1B28FF73F4734
```

#### 2. Check UNL Publisher Connectivity

```bash
curl -I https://vl.xrplf.org
```

If unreachable:
- Check DNS resolution
- Verify outbound HTTPS is allowed
- Try alternative UNL publishers

#### 3. Verify Validator Token

Ensure `[validator_token]` section exists in config:
```ini
[validator_token]
YOUR_VALIDATOR_TOKEN_HERE
```

---

## Peer Connection Problems

### Symptoms
- Low peer count (< 10)
- Frequent peer disconnections
- Network isolation

### Diagnosis

```bash
# List peers
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"peers","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result.peers[] | {address, latency, uptime}'

# Check for connection errors in logs
grep -i "peer" /var/log/rippled/debug.log | tail -100
```

### Solutions

#### 1. Firewall Configuration

```bash
# Check if port 51235 is open
sudo netstat -tlnp | grep 51235

# AWS Security Group - ensure these rules exist:
# Inbound: TCP 51235 from 0.0.0.0/0
# Inbound: UDP 51235 from 0.0.0.0/0
```

#### 2. Add Fixed Peers

Add known good peers to `rippled.cfg`:
```ini
[ips_fixed]
s.altnet.rippletest.net 51235
```

#### 3. Check for NAT Issues

If behind NAT:
```ini
[peer_private]
0
```

---

## Performance Issues

### Symptoms
- High CPU usage
- Slow RPC responses
- Memory exhaustion

### Diagnosis

```bash
# Check system resources
htop

# Check rippled memory usage
docker stats rippled

# Check load factor
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"server_info","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result.info.load_factor'
```

### Solutions

#### 1. Increase Node Size

In `rippled.cfg`:
```ini
[node_size]
large  # or huge for high traffic
```

#### 2. Optimize Database

```ini
[node_db]
type=NuDB
path=/var/lib/rippled/db/nudb
online_delete=256  # Keep less history
advisory_delete=0
```

#### 3. Upgrade Instance

For validators, use memory-optimized instances:
- AWS: r5.xlarge or r5.2xlarge
- Minimum 32GB RAM for production

---

## Amendment Blocked

### Symptoms
- `amendment_blocked: true` in server_info
- Node not validating

### Diagnosis

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"server_info","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result.info.amendment_blocked'

# Check feature status
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"feature","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result'
```

### Solution

**Upgrade rippled immediately!**

```bash
# Pull latest image
docker pull xrpllabsofficial/xrpld:latest

# Restart
docker-compose down
docker-compose up -d
```

---

## Database Issues

### Symptoms
- Corruption errors in logs
- Node fails to start
- Unexpected restarts

### Diagnosis

```bash
# Check logs for database errors
grep -i "database\|corrupt\|error" /var/log/rippled/debug.log
```

### Solutions

#### 1. Clear Database and Re-sync

```bash
docker-compose down
rm -rf /var/lib/rippled/db/*
docker-compose up -d
```

#### 2. Check Disk Health

```bash
# Check for disk errors
dmesg | grep -i "error\|fail\|io"

# Check disk SMART status
sudo smartctl -a /dev/nvme0n1
```

---

## Network Connectivity

### Network Diagram for Troubleshooting

```
                     Internet
                         │
                    ┌────┴────┐
                    │ Firewall │
                    └────┬────┘
                         │ Port 51235
                ┌────────┴────────┐
                │                 │
            ┌───┴───┐        ┌───┴───┐
            │ Peer  │        │ Peer  │
            │ Node  │◄──────►│ Node  │
            └───────┘        └───────┘
                    ▲
                    │ Port 51235
                    ▼
            ┌─────────────┐
            │  Your Node  │
            │ ┌─────────┐ │
            │ │ rippled │ │
            │ └─────────┘ │
            └─────────────┘
```

### Check Commands

```bash
# Test outbound connectivity
curl -sf https://s.altnet.rippletest.net:51235 || echo "Cannot reach testnet"

# Check if listening
sudo netstat -tlnp | grep 51235

# Test inbound (from another server)
nc -zv YOUR_SERVER_IP 51235
```

---

## Monitoring Alerts

### Alert: ValidatorDown

**Meaning**: Node is unreachable

**Actions**:
1. Check if Docker container is running: `docker ps | grep rippled`
2. Check container logs: `docker logs rippled --tail 100`
3. Restart if needed: `docker-compose restart rippled`

### Alert: ConsensusNotParticipating

**Meaning**: Validator not proposing in consensus

**Actions**:
1. Check server state
2. Verify validator token is configured
3. Check UNL connectivity

### Alert: LowPeerCount

**Meaning**: Insufficient peer connections

**Actions**:
1. Check firewall rules
2. Verify port 51235 is accessible
3. Add fixed peers to configuration

### Alert: LedgerStalled

**Meaning**: Ledger not advancing

**Actions**:
1. Check peer connectivity
2. Verify time synchronization
3. Check for database issues

---

## Support Resources

- **XRPL Documentation**: https://xrpl.org/docs
- **Xahau Documentation**: https://docs.xahau.network
- **XRPL Developer Discord**: https://discord.gg/xrpl
- **GitHub Issues**: https://github.com/ripple/rippled/issues
