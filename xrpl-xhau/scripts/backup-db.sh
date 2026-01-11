#!/bin/bash
# =============================================================================
# XRPL/Xahau Database Backup Script
# =============================================================================
# This script creates backups of the validator database and configuration

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-/opt/xrpl/backups}"
DATA_DIR="${DATA_DIR:-/var/lib/rippled}"
CONFIG_DIR="${CONFIG_DIR:-/opt/xrpl/configs}"
KEYS_DIR="${KEYS_DIR:-/opt/xrpl/keys}"
S3_BUCKET="${S3_BUCKET:-}"
RETENTION_DAYS=${RETENTION_DAYS:-7}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Timestamp for backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="xrpl-backup-${TIMESTAMP}"

echo -e "${GREEN}=== XRPL Validator Backup ===${NC}"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Function to check if rippled is running
is_rippled_running() {
    docker ps --filter "name=rippled" --format "{{.Names}}" | grep -q rippled
}

# Backup configuration files
echo -e "${GREEN}Backing up configuration files...${NC}"
if [ -d "$CONFIG_DIR" ]; then
    cp -r "$CONFIG_DIR" "$BACKUP_DIR/$BACKUP_NAME/configs"
    echo "  ✓ Configuration files backed up"
else
    echo -e "  ${YELLOW}⚠ Config directory not found: $CONFIG_DIR${NC}"
fi

# Backup validator keys (CRITICAL)
echo -e "${GREEN}Backing up validator keys...${NC}"
if [ -d "$KEYS_DIR" ]; then
    cp -r "$KEYS_DIR" "$BACKUP_DIR/$BACKUP_NAME/keys"
    chmod -R 600 "$BACKUP_DIR/$BACKUP_NAME/keys"
    echo "  ✓ Validator keys backed up"
else
    echo -e "  ${YELLOW}⚠ Keys directory not found: $KEYS_DIR${NC}"
fi

# Backup database (optional - can be large)
BACKUP_DB=${BACKUP_DB:-false}
if [ "$BACKUP_DB" = "true" ]; then
    echo -e "${GREEN}Backing up database...${NC}"
    
    if is_rippled_running; then
        echo -e "  ${YELLOW}⚠ rippled is running. Stopping for consistent backup...${NC}"
        docker stop rippled
        DB_WAS_RUNNING=true
    fi
    
    if [ -d "$DATA_DIR" ]; then
        # Use tar with compression
        tar -czf "$BACKUP_DIR/$BACKUP_NAME/database.tar.gz" -C "$DATA_DIR" .
        echo "  ✓ Database backed up ($(du -h "$BACKUP_DIR/$BACKUP_NAME/database.tar.gz" | cut -f1))"
    else
        echo -e "  ${YELLOW}⚠ Data directory not found: $DATA_DIR${NC}"
    fi
    
    if [ "$DB_WAS_RUNNING" = "true" ]; then
        echo "  Restarting rippled..."
        docker start rippled
    fi
else
    echo -e "${YELLOW}Skipping database backup (set BACKUP_DB=true to enable)${NC}"
fi

# Create backup manifest
echo -e "${GREEN}Creating backup manifest...${NC}"
cat > "$BACKUP_DIR/$BACKUP_NAME/manifest.json" << EOF
{
    "backup_name": "$BACKUP_NAME",
    "timestamp": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "includes": {
        "configs": $([ -d "$BACKUP_DIR/$BACKUP_NAME/configs" ] && echo "true" || echo "false"),
        "keys": $([ -d "$BACKUP_DIR/$BACKUP_NAME/keys" ] && echo "true" || echo "false"),
        "database": $([ -f "$BACKUP_DIR/$BACKUP_NAME/database.tar.gz" ] && echo "true" || echo "false")
    },
    "sizes": {
        "configs": "$(du -sh "$BACKUP_DIR/$BACKUP_NAME/configs" 2>/dev/null | cut -f1 || echo "N/A")",
        "keys": "$(du -sh "$BACKUP_DIR/$BACKUP_NAME/keys" 2>/dev/null | cut -f1 || echo "N/A")",
        "database": "$(du -sh "$BACKUP_DIR/$BACKUP_NAME/database.tar.gz" 2>/dev/null | cut -f1 || echo "N/A")"
    }
}
EOF

# Create compressed archive
echo -e "${GREEN}Creating compressed archive...${NC}"
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"
echo "  ✓ Backup archive created: ${BACKUP_NAME}.tar.gz"

# Calculate checksum
sha256sum "${BACKUP_NAME}.tar.gz" > "${BACKUP_NAME}.tar.gz.sha256"
echo "  ✓ Checksum created"

# Upload to S3 if configured
if [ -n "$S3_BUCKET" ]; then
    echo -e "${GREEN}Uploading to S3...${NC}"
    aws s3 cp "${BACKUP_NAME}.tar.gz" "s3://${S3_BUCKET}/xrpl-backups/${BACKUP_NAME}.tar.gz"
    aws s3 cp "${BACKUP_NAME}.tar.gz.sha256" "s3://${S3_BUCKET}/xrpl-backups/${BACKUP_NAME}.tar.gz.sha256"
    echo "  ✓ Uploaded to s3://${S3_BUCKET}/xrpl-backups/"
fi

# Cleanup old backups
echo -e "${GREEN}Cleaning up old backups (> ${RETENTION_DAYS} days)...${NC}"
find "$BACKUP_DIR" -name "xrpl-backup-*.tar.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "xrpl-backup-*.tar.gz.sha256" -mtime +$RETENTION_DAYS -delete
echo "  ✓ Old backups cleaned up"

# Summary
echo ""
echo -e "${GREEN}=== Backup Complete ===${NC}"
echo "Backup file: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
echo "Size: $(du -h "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)"
echo ""
echo -e "${YELLOW}Remember to store validator key backups in a secure, offline location!${NC}"
