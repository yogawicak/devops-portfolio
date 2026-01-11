# XRPL/Xahau Monitoring Guide

## Overview

This project uses a comprehensive monitoring stack:

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation
- **Alertmanager**: Alert routing and notification

## Quick Start

```bash
cd docker/monitoring
docker-compose up -d
```

Access Grafana at `http://localhost:3000` (admin/admin)

## Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `xrpl_server_state` | Validator state | != full/proposing |
| `xrpl_peers_connected` | Peer count | < 10 |
| `xrpl_ledger_age` | Seconds behind | > 60s |
| `node_cpu_usage` | CPU utilization | > 80% |
| `node_memory_usage` | Memory usage | > 85% |
| `node_disk_usage` | Disk space | > 85% |

## Alert Severity

- **Critical**: Immediate response required
- **Warning**: Investigation needed
- **Info**: Informational only

## Dashboards

1. **Validator Overview**: Node health and consensus
2. **Network Health**: Peer connections and latency
3. **Resource Usage**: CPU, memory, disk
4. **Ledger Progress**: Sync status and history
