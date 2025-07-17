#!/bin/bash
set -e

echo "🚀 Starting retryable-monitor entrypoint script..."

RPC_ENDPOINT="${RPC_ENDPOINT:-https://sepolia-rollup.arbitrum.io/rpc}"
ORIGINAL_CONFIG_PATH="config.json"
TEMP_CONFIG_PATH="replaced_config.json"
BLOCK_TRACK_FILE="/data/last_block.txt"

# Check if original config file exists
if [ ! -f "$ORIGINAL_CONFIG_PATH" ]; then
  echo "❌ Missing config.json at $ORIGINAL_CONFIG_PATH"
  exit 1
fi

# Copy config and substitute parent RPC URL
cp "$ORIGINAL_CONFIG_PATH" "$TEMP_CONFIG_PATH"
sed -i "s|__PARENT_RPC_URL__|$RPC_ENDPOINT|g" "$TEMP_CONFIG_PATH"

# Get latest block
LATEST_BLOCK_HEX=$(curl -s -X POST "$RPC_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | jq -r '.result')

if [ -z "$LATEST_BLOCK_HEX" ] || [ "$LATEST_BLOCK_HEX" == "null" ]; then
  echo "❌ Failed to fetch latest block from RPC endpoint"
  exit 1
fi

LATEST_BLOCK_DEC=$((16#${LATEST_BLOCK_HEX:2}))

# Load previous block from PVC or default
if [ -f "$BLOCK_TRACK_FILE" ]; then
  FROM_BLOCK=$(cat "$BLOCK_TRACK_FILE")
  echo "📁 Loaded last block from PVC: $FROM_BLOCK"
else
  FROM_BLOCK=$((LATEST_BLOCK_DEC - 5000))
  echo "🆕 No previous block found. Defaulting from block: $FROM_BLOCK"
fi

# Validate block range
if [ "$FROM_BLOCK" -ge "$LATEST_BLOCK_DEC" ]; then
  FROM_BLOCK=$((LATEST_BLOCK_DEC - 5000))
  echo "⚠️ From block ahead of latest. Resetting to: $FROM_BLOCK"
fi

echo "✅ Using RPC endpoint: ${RPC_ENDPOINT:0:15}..."
echo "🔢 Latest block: $LATEST_BLOCK_DEC"
echo "🚀 Starting retryable-monitor from block: $FROM_BLOCK"

# Run monitor (assumed to complete fully)
node dist/retryable-monitor/index.js \
  --fromBlock "$FROM_BLOCK" \
  --toBlock "$LATEST_BLOCK_DEC" \
  --enableAlerting \
  --configPath "$TEMP_CONFIG_PATH"

# Ensure the directory exists before writing
mkdir -p "$(dirname "$BLOCK_TRACK_FILE")"

# Save toBlock to PVC for next run
echo "$LATEST_BLOCK_DEC" > "$BLOCK_TRACK_FILE"
echo "💾 Saved last processed block to $BLOCK_TRACK_FILE: $LATEST_BLOCK_DEC"
