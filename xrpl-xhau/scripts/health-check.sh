#!/bin/bash
# =============================================================================
# XRPL/Xahau Validator Health Check Script
# =============================================================================
# This script performs comprehensive health checks on the validator node
# Exit codes: 0 = healthy, 1 = warning, 2 = critical

set -e

# Configuration
RPC_URL="${RPC_URL:-http://127.0.0.1:6006}"
MIN_PEERS=${MIN_PEERS:-10}
MAX_LEDGER_AGE=${MAX_LEDGER_AGE:-60}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Exit code tracking
EXIT_CODE=0

# Helper function to make RPC calls
rpc_call() {
    local method=$1
    curl -sf -X POST -H "Content-Type: application/json" \
        -d "{\"method\": \"$method\", \"params\": [{}]}" \
        "$RPC_URL" 2>/dev/null
}

# Helper function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        ok)
            echo -e "[${GREEN}OK${NC}] $message"
            ;;
        warn)
            echo -e "[${YELLOW}WARN${NC}] $message"
            if [ $EXIT_CODE -lt 1 ]; then EXIT_CODE=1; fi
            ;;
        crit)
            echo -e "[${RED}CRIT${NC}] $message"
            EXIT_CODE=2
            ;;
        info)
            echo -e "[INFO] $message"
            ;;
    esac
}

echo "=============================================="
echo "XRPL Validator Health Check"
echo "Time: $(date)"
echo "=============================================="
echo ""

# Check 1: Server connectivity
echo "--- Server Connectivity ---"
server_info=$(rpc_call "server_info")
if [ -z "$server_info" ]; then
    print_status crit "Cannot connect to rippled at $RPC_URL"
    exit 2
fi
print_status ok "Connected to rippled"

# Check 2: Server state
echo ""
echo "--- Server State ---"
server_state=$(echo "$server_info" | jq -r '.result.info.server_state // "unknown"')
case $server_state in
    "full"|"proposing"|"validating")
        print_status ok "Server state: $server_state"
        ;;
    "connected"|"syncing"|"tracking")
        print_status warn "Server state: $server_state (still syncing)"
        ;;
    *)
        print_status crit "Server state: $server_state (unhealthy)"
        ;;
esac

# Check 3: Validator status
is_validator=$(echo "$server_info" | jq -r '.result.info.validation_quorum // 0')
if [ "$is_validator" != "0" ]; then
    print_status info "Node is configured as a validator"
fi

# Check 4: Ledger information
echo ""
echo "--- Ledger Status ---"
ledger_seq=$(echo "$server_info" | jq -r '.result.info.validated_ledger.seq // 0')
ledger_age=$(echo "$server_info" | jq -r '.result.info.validated_ledger.age // 999')

print_status info "Current ledger: $ledger_seq"
print_status info "Ledger age: ${ledger_age}s"

if [ "$ledger_age" -gt "$MAX_LEDGER_AGE" ]; then
    print_status crit "Ledger is stale (age > ${MAX_LEDGER_AGE}s)"
elif [ "$ledger_age" -gt 30 ]; then
    print_status warn "Ledger is slightly behind (age > 30s)"
else
    print_status ok "Ledger is current"
fi

# Check 5: Peer connections
echo ""
echo "--- Peer Connections ---"
peers_info=$(rpc_call "peers")
peer_count=$(echo "$peers_info" | jq -r '.result.peers | length // 0')

print_status info "Connected peers: $peer_count"
if [ "$peer_count" -lt 5 ]; then
    print_status crit "Critically low peer count (< 5)"
elif [ "$peer_count" -lt "$MIN_PEERS" ]; then
    print_status warn "Low peer count (< $MIN_PEERS)"
else
    print_status ok "Peer count is healthy"
fi

# Check 6: Load and performance
echo ""
echo "--- Load Status ---"
load_factor=$(echo "$server_info" | jq -r '.result.info.load_factor // 1')
load_base=$(echo "$server_info" | jq -r '.result.info.load_factor_server // 1')

print_status info "Load factor: $load_factor (base: $load_base)"
if [ "$load_factor" -gt 1000 ]; then
    print_status crit "High load factor"
elif [ "$load_factor" -gt 256 ]; then
    print_status warn "Elevated load factor"
else
    print_status ok "Load factor is normal"
fi

# Check 7: Uptime
echo ""
echo "--- Uptime ---"
uptime_seconds=$(echo "$server_info" | jq -r '.result.info.uptime // 0')
uptime_hours=$((uptime_seconds / 3600))
uptime_days=$((uptime_hours / 24))

print_status info "Uptime: ${uptime_days}d ${uptime_hours}h"
if [ "$uptime_seconds" -lt 300 ]; then
    print_status warn "Node recently restarted (< 5 minutes ago)"
fi

# Check 8: Amendment status
echo ""
echo "--- Amendment Status ---"
amendments=$(echo "$server_info" | jq -r '.result.info.amendment_blocked // false')
if [ "$amendments" == "true" ]; then
    print_status crit "Node is AMENDMENT BLOCKED - upgrade required!"
else
    print_status ok "No amendment blocks"
fi

# Check 9: System resources
echo ""
echo "--- System Resources ---"

# CPU usage
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' 2>/dev/null || echo "N/A")
if [ "$cpu_usage" != "N/A" ]; then
    print_status info "CPU usage: ${cpu_usage}%"
fi

# Memory usage
mem_info=$(free -m 2>/dev/null || echo "")
if [ -n "$mem_info" ]; then
    mem_total=$(echo "$mem_info" | awk '/Mem:/ {print $2}')
    mem_used=$(echo "$mem_info" | awk '/Mem:/ {print $3}')
    mem_percent=$((mem_used * 100 / mem_total))
    print_status info "Memory usage: ${mem_percent}% (${mem_used}MB / ${mem_total}MB)"
    if [ "$mem_percent" -gt 90 ]; then
        print_status warn "High memory usage"
    fi
fi

# Disk usage
disk_usage=$(df -h /var/lib/rippled 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "N/A")
if [ "$disk_usage" != "N/A" ]; then
    print_status info "Disk usage: ${disk_usage}%"
    if [ "$disk_usage" -gt 85 ]; then
        print_status warn "High disk usage (> 85%)"
    elif [ "$disk_usage" -gt 95 ]; then
        print_status crit "Critical disk usage (> 95%)"
    fi
fi

# Summary
echo ""
echo "=============================================="
echo "Health Check Summary"
echo "=============================================="
case $EXIT_CODE in
    0)
        echo -e "${GREEN}Status: HEALTHY${NC}"
        ;;
    1)
        echo -e "${YELLOW}Status: WARNING${NC}"
        ;;
    2)
        echo -e "${RED}Status: CRITICAL${NC}"
        ;;
esac

exit $EXIT_CODE
