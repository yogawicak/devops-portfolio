# XRPL/Xahau Validator Setup Guide

This guide covers setting up an XRPL or Xahau validator node.

## Prerequisites

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 4 cores | 8+ cores |
| RAM | 16 GB | 32 GB |
| Storage | 200 GB SSD | 500 GB NVMe |

## Quick Start

```bash
# 1. Deploy infrastructure
cd terraform
terraform init && terraform apply -var-file="production.tfvars"

# 2. SSH to validator
ssh -i key.pem ubuntu@<validator-ip>

# 3. Generate validator keys
./scripts/generate-validator-keys.sh

# 4. Start validator
docker-compose up -d

# 5. Verify
./scripts/health-check.sh
```

## Network Configuration

### Mainnet
```ini
[network_id]
0

[ips]
r.ripple.com 51235
```

### Testnet
```ini
[network_id]
1

[ips]
s.altnet.rippletest.net 51235
```

### Xahau
```ini
[network_id]
21337

[features]
HooksV1
```

## Verification

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"method":"server_info","params":[{}]}' \
  http://127.0.0.1:6006/ | jq '.result.info.server_state'
```

Expected state: `full`, `proposing`, or `validating`

## Maintenance

- Daily: Run `./scripts/health-check.sh`
- Weekly: Run `./scripts/backup-db.sh`
- Monthly: Check for rippled updates

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues.
