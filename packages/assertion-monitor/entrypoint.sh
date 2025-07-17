#!/bin/bash
echo "🚀 Starting assertion-monitor entrypoint script..."

# ✅ Use real env vars if set, otherwise fall back to dummy values
export ASSERTION_MONITORING_SLACK_TOKEN="${ASSERTION_MONITORING_SLACK_TOKEN:-dummy-token}"
export ASSERTION_MONITORING_SLACK_CHANNEL="${ASSERTION_MONITORING_SLACK_CHANNEL:-#dummy-channel}"

# Use env var for RPC endpoint, fallback to default
RPC_ENDPOINT="${RPC_ENDPOINT:-https://sepolia-rollup.arbitrum.io/rpc}"

# Define original config path and temporary copy location
ORIGINAL_CONFIG_PATH="config.json"
TEMP_CONFIG_PATH="replaced_config.json"

# Check that original config file exists
if [ ! -f "$ORIGINAL_CONFIG_PATH" ]; then
  echo "❌ Missing config.json at $ORIGINAL_CONFIG_PATH"
  exit 1
fi

# Copy config to a writable temp location
cp "$ORIGINAL_CONFIG_PATH" "$TEMP_CONFIG_PATH"

# Replace placeholder in temp config file with actual RPC endpoint
sed -i "s|__PARENT_RPC_URL__|$RPC_ENDPOINT|g" "$TEMP_CONFIG_PATH"

echo "✅ Using RPC endpoint: ${RPC_ENDPOINT:0:15}..."
echo "ASSERTION_MONITORING_SLACK_TOKEN: ${ASSERTION_MONITORING_SLACK_TOKEN:0:5}..."
echo "ASSERTION_MONITORING_SLACK_CHANNEL: ${ASSERTION_MONITORING_SLACK_CHANNEL:0:5}..."

# Start the monitor script with the modified temp config path
exec  node dist/assertion-monitor/main.js \
  --enableAlerting \
  --configPath "$TEMP_CONFIG_PATH"

