#!/bin/bash
# =============================================================================
# XRPL/Xahau Validator Key Generation Script
# =============================================================================
# This script generates validator keys using the validator-keys tool
# The generated token should be added to your rippled.cfg

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
KEYS_DIR="${KEYS_DIR:-/opt/xrpl/keys}"
VALIDATOR_KEYS_IMAGE="xrpllabsofficial/validator-keys:latest"

echo -e "${GREEN}=== XRPL Validator Key Generation ===${NC}"
echo ""

# Create keys directory
mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"

# Check if keys already exist
if [ -f "$KEYS_DIR/validator-keys.json" ]; then
    echo -e "${YELLOW}WARNING: Validator keys already exist at $KEYS_DIR/validator-keys.json${NC}"
    echo -e "${YELLOW}If you generate new keys, you will need to re-register your validator.${NC}"
    read -p "Do you want to generate new keys? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    # Backup existing keys
    backup_file="$KEYS_DIR/validator-keys.json.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$KEYS_DIR/validator-keys.json" "$backup_file"
    echo -e "${GREEN}Backed up existing keys to: $backup_file${NC}"
fi

# Generate keys using Docker
echo -e "${GREEN}Generating validator keys...${NC}"

docker run --rm \
    -v "$KEYS_DIR:/keys" \
    "$VALIDATOR_KEYS_IMAGE" \
    create_keys --keyfile /keys/validator-keys.json

echo ""
echo -e "${GREEN}Validator keys generated successfully!${NC}"
echo -e "Keys saved to: $KEYS_DIR/validator-keys.json"
echo ""

# Read and display the validator public key
if command -v jq &> /dev/null; then
    public_key=$(jq -r '.public_key' "$KEYS_DIR/validator-keys.json")
    echo -e "${GREEN}Validator Public Key:${NC}"
    echo "$public_key"
    echo ""
fi

# Generate token for configuration
echo -e "${GREEN}Generating validator token...${NC}"

docker run --rm \
    -v "$KEYS_DIR:/keys" \
    "$VALIDATOR_KEYS_IMAGE" \
    create_token --keyfile /keys/validator-keys.json > "$KEYS_DIR/validator-token.txt"

token=$(cat "$KEYS_DIR/validator-token.txt")

echo ""
echo -e "${GREEN}=== IMPORTANT: Add this to your rippled.cfg ===${NC}"
echo ""
echo "[validator_token]"
echo "$token"
echo ""

# Create a config snippet
cat > "$KEYS_DIR/validator-config-snippet.txt" << EOF
# Add this to your rippled.cfg or xahaud.cfg

[validator_token]
$token
EOF

echo -e "${GREEN}Configuration snippet saved to: $KEYS_DIR/validator-config-snippet.txt${NC}"
echo ""

# Security reminders
echo -e "${YELLOW}=== SECURITY REMINDERS ===${NC}"
echo "1. Keep your validator-keys.json file SECURE and BACKED UP"
echo "2. Never share your private keys"
echo "3. The validator token is derived from your keys and can be regenerated"
echo "4. Store a backup of validator-keys.json in a secure, offline location"
echo ""

# Set proper permissions
chmod 600 "$KEYS_DIR/validator-keys.json"
chmod 600 "$KEYS_DIR/validator-token.txt"
chmod 600 "$KEYS_DIR/validator-config-snippet.txt"

echo -e "${GREEN}Key generation complete!${NC}"
