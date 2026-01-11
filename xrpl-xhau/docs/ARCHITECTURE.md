# Architecture Overview

## Infrastructure Design

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
├─────────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  Public Subnet                    Private Subnet           │ │
│  │  ┌─────────┐ ┌─────────┐         ┌───────────────────┐     │ │
│  │  │ Bastion │ │   NAT   │         │ Validator Node    │     │ │
│  │  │  Host   │ │ Gateway │◄───────►│ - rippled/xahaud  │     │ │
│  │  └─────────┘ └─────────┘         │ - Node Exporter   │     │ │
│  │                                  │ - Promtail        │     │ │
│  │                                  └───────────────────┘     │ │
│  │                                  ┌───────────────────┐     │ │
│  │                                  │ Monitoring Stack  │     │ │
│  │                                  │ - Prometheus      │     │ │
│  │                                  │ - Grafana         │     │ │
│  │                                  │ - Loki            │     │ │
│  │                                  └───────────────────┘     │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### Validator Node
- **rippled/xahaud**: XRPL validator software
- **Node Exporter**: System metrics
- **Promtail**: Log shipping to Loki

### Monitoring Stack
- **Prometheus**: Metrics storage and alerting
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **Alertmanager**: Alert routing

### Security
- Private subnet for validators
- Bastion host for SSH access
- Security groups with minimal exposure
- Only port 51235 exposed publicly

## Data Flow

1. Validator connects to XRPL network peers (port 51235)
2. Node Exporter collects system metrics
3. Promtail ships logs to Loki
4. Prometheus scrapes metrics
5. Grafana displays dashboards
6. Alertmanager sends notifications
