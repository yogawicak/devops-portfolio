# XRPL/Xahau Validator Infrastructure

A production-ready DevOps infrastructure for running XRPL/Xahau validator nodes on AWS. This project demonstrates best practices for validator operations, monitoring, logging, and troubleshooting.

![XRPL](https://img.shields.io/badge/XRPL-Validator-blue)
![Xahau](https://img.shields.io/badge/Xahau-Testnet-green)
![Terraform](https://img.shields.io/badge/Terraform-IaC-purple)
![Docker](https://img.shields.io/badge/Docker-Container-blue)
![AWS](https://img.shields.io/badge/AWS-Cloud-orange)

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                   │
├─────────────────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                                      │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Public Subnet (10.0.1.0/24)                                       │ │
│  │  ┌─────────────────────┐                                            │ │
│  │  │   NAT Gateway       │                                            │ │
│  │  │                     │                                            │ │
│  │  └─────────────────────┘                                            │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Private Subnet (10.0.2.0/24)                                      │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │            Validator Node (r5.large)                        │   │ │
│  │  │  ┌───────────────┐ ┌───────────────┐ ┌──────────────────┐   │   │ │
│  │  │  │   rippled/    │ │  Prometheus   │ │     Promtail     │   │   │ │
│  │  │  │   xahaud      │ │   Exporter    │ │                  │   │   │ │
│  │  │  └───────────────┘ └───────────────┘ └──────────────────┘   │   │ │
│  │  │                 │                                            │   │ │
│  │  │      ┌──────────┴──────────┐                                 │   │ │
│  │  │      │   EBS Volume        │                                 │   │ │
│  │  │      │   (500GB gp3)       │                                 │   │ │
│  │  │      │   Ledger Storage    │                                 │   │ │
│  │  │      └─────────────────────┘                                 │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │  Private Subnet (10.0.3.0/24)                                      │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │            Monitoring Stack (t3.medium)                     │   │ │
│  │  │  ┌───────────────┐ ┌───────────────┐ ┌──────────────────┐   │   │ │
│  │  │  │  Prometheus   │ │   Grafana     │ │      Loki        │   │   │ │
│  │  │  │               │ │               │ │                  │   │   │ │
│  │  │  └───────────────┘ └───────────────┘ └──────────────────┘   │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- Docker & Docker Compose
- SSH key pair for EC2 access

### 1. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan -var-file="production.tfvars"
terraform apply -var-file="production.tfvars"
```

### 2. Configure Validator

```bash
# SSH into validator node
ssh -i your-key.pem ubuntu@<validator-ip>

# Generate validator keys
./scripts/generate-validator-keys.sh

# Start validator
docker-compose up -d
```

### 3. Deploy Monitoring

```bash
cd docker/monitoring
docker-compose up -d
```

## 📁 Project Structure

```
.
├── terraform/                  # AWS Infrastructure as Code
│   ├── main.tf                 # Main configuration
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── vpc.tf                  # VPC configuration
│   ├── ec2.tf                  # EC2 instances
│   ├── security-groups.tf      # Security group rules
│   └── production.tfvars       # Production variables
├── docker/                     # Container configurations
│   ├── docker-compose.yml      # Validator stack
│   └── monitoring/
│       └── docker-compose.yml  # Monitoring stack
├── configs/                    # XRPL/Xahau configurations
│   ├── rippled.cfg.template    # rippled configuration
│   ├── xahaud.cfg.template     # xahaud configuration
│   ├── validators.txt          # Validator list
│   └── unl/                    # UNL configurations
├── monitoring/                 # Observability stack
│   ├── prometheus/             # Prometheus configs
│   ├── grafana/                # Grafana dashboards
│   └── alertmanager/           # Alert configurations
├── logging/                    # Centralized logging
│   ├── loki/                   # Loki configuration
│   └── promtail/               # Promtail configuration
├── scripts/                    # Operational scripts
│   ├── generate-validator-keys.sh
│   ├── health-check.sh
│   └── backup-db.sh
└── docs/                       # Documentation
    ├── ARCHITECTURE.md
    ├── TROUBLESHOOTING.md
    ├── VALIDATOR-SETUP.md
    └── MONITORING.md
```

## 🔧 Configuration

### XRPL Ports

| Port  | Protocol | Purpose                |
| ----- | -------- | ---------------------- |
| 51235 | TCP/UDP  | Peer-to-peer protocol  |
| 6006  | TCP      | Admin RPC (local only) |
| 5005  | TCP      | Public RPC (optional)  |
| 6007  | TCP      | Admin WebSocket        |

### Environment Variables

| Variable          | Description                 | Default     |
| ----------------- | --------------------------- | ----------- |
| `NETWORK_ID`      | Network identifier          | `1`         |
| `VALIDATOR_TOKEN` | Validator token (from keys) | Required    |
| `UNL_URL`         | UNL publisher URL           | Mainnet UNL |

## 📊 Monitoring

### Grafana Dashboards

- **Validator Overview**: Node status, consensus participation, amendment support
- **Network Health**: Peer connections, latency, bandwidth
- **Resource Utilization**: CPU, memory, disk I/O
- **Ledger Progress**: Ledger sequence, close time, transaction counts

### Alerting Rules

| Alert              | Condition                      | Severity |
| ------------------ | ------------------------------ | -------- |
| `ValidatorOffline` | Node unreachable > 2min        | Critical |
| `ConsensusFailure` | Not participating in consensus | Critical |
| `HighCPUUsage`     | CPU > 80% for 5min             | Warning  |
| `DiskSpaceLow`     | Disk usage > 85%               | Warning  |
| `PeerCountLow`     | Connected peers < 10           | Warning  |

## 🔒 Security Best Practices

1. **Network Isolation**: Validators run in private subnets
2. **Minimal Exposure**: Only peer port (51235) exposed to public
3. **Key Management**: Validator keys stored in AWS Secrets Manager
4. **Firewall Rules**: Strict security group configurations

## 📚 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md)
- [Validator Setup](docs/VALIDATOR-SETUP.md)
- [Monitoring Guide](docs/MONITORING.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## 🤝 Author

**Yoga Wicaksono** - DevOps Engineer specializing in XRPL/Xahau infrastructure

## 📄 License

MIT License - See [LICENSE](LICENSE) for details
