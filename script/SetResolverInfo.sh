#!/bin/bash

# Set resolver-info text record for CCResolver on Ethereum Sepolia
# This script uses the resolver-info standard from:
# https://github.com/nxt3d/ensips/blob/resolver-info-metadata/ensips/resolver-info-text-record.md

# Load environment variables
source .env

# Configuration
RESOLVER_ADDRESS="0xCE943F957FC46a8d048505E6949e32201a128f84"
RPC_URL="$SEPOLIA_RPC_URL"
PRIVATE_KEY="$DEPLOYER_PRIVATE_KEY"

# Resolver info content (Markdown with embedded JSON)
RESOLVER_INFO='# CCResolver v0.1.0

**Upgradable:** No  
**Author:** @nxt3d

ENS resolver with controlled accounts verification via ERC-8092.

Query: `eth.ecs.controlled-accounts:<id>` returns YAML of verified parent-child accounts.

```json
{
  "version": "0.1.0",
  "upgradable": false,
  "features": ["controlled-accounts", "text", "data", "addr", "contenthash"],
  "standards": ["ERC-8092", "ERC-7930", "ENSIP-5", "ENSIP-10"],
  "network": "sepolia",
  "associationsStore": "0x44CcD9b079C4DEf953A6ec9fC7F63cDC0cb14F50",
  "docs": "https://github.com/nxt3d/AssociatedAccounts"
}
```'

# Escape for shell (replace newlines with \n)
RESOLVER_INFO_ESCAPED=$(echo "$RESOLVER_INFO" | awk '{printf "%s\\n", $0}')

echo "========================================"
echo "Setting resolver-info for CCResolver"
echo "========================================"
echo ""
echo "Resolver: $RESOLVER_ADDRESS"
echo "Network: Ethereum Sepolia"
echo ""

# Call setText function
# setText(string calldata _key, string calldata _value)
cast send $RESOLVER_ADDRESS \
  "setText(string,string)" \
  "resolver-info" \
  "$RESOLVER_INFO_ESCAPED" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

echo ""
echo "✅ Resolver info set successfully!"
echo ""
echo "Verify by reading the text record:"
echo "cast call $RESOLVER_ADDRESS \"text(bytes32,string)(string)\" 0x0000000000000000000000000000000000000000000000000000000000000000 \"resolver-info\" --rpc-url $RPC_URL"

