# ENS Query Scripts

JavaScript utilities for querying CCResolver via ENS.

## Setup

Install dependencies:

```bash
npm install
```

## Usage

### Query Controlled Accounts

Query the live `controlled-accounts.ecs.eth` on Sepolia:

```bash
# Query ID 0 (default)
npm run query-ens

# Query specific ID
npm run query-ens 1

# Or use node directly
node scripts/query-ens.js 0
```

**Example Output:**

```
🔍 Querying controlled-accounts.ecs.eth on Sepolia...

📡 Resolving ENS name: controlled-accounts.ecs.eth
✅ Resolver found: 0xAE5A879A021982B65A691dFdcE83528e8e13dFd3

📋 Querying text record: "eth.ecs.controlled-accounts:0"
✅ Data found!

📄 Raw YAML Output:
────────────────────────────────────────────────────────────
id: 0
registeredAt: 1765302228
parent: "0x0001000003aa36a7144d45cd7472f2c46e81734c561a2d0b4b66c8fefe"
children:
  - "0x0001000003aa36a714f935f966a073746a9ee0f6a685a41da23a64e1d1"
  - "0x0001000003aa36a714cc8d7b159eafa8a2c4ca5c88c3f6b760761dbf28"
────────────────────────────────────────────────────────────

🔓 Decoded Data:
────────────────────────────────────────────────────────────
ID: 0
Registered At: 1765302228 (2025-12-09T19:03:48.000Z)

👤 Parent Account:
   Address: 0x4D45CD7472f2C46e81734c561a2D0b4B66C8FEFe
   Chain: 11155111 (EIP-155)

👥 Controlled Accounts (2):
   1. 0xf935F966A073746a9Ee0F6a685A41dA23a64E1d1
      Chain: 11155111
   2. 0xcc8D7b159eaFA8A2C4CA5C88c3F6B760761dBF28
      Chain: 11155111
────────────────────────────────────────────────────────────

🔗 Verify on Etherscan:
   Resolver: https://sepolia.etherscan.io/address/0xAE5A879A021982B65A691dFdcE83528e8e13dFd3
   Parent: https://sepolia.etherscan.io/address/0x4D45CD7472f2C46e81734c561a2D0b4B66C8FEFe
   Child 1: https://sepolia.etherscan.io/address/0xf935F966A073746a9Ee0F6a685A41dA23a64E1d1
   Child 2: https://sepolia.etherscan.io/address/0xcc8D7b159eaFA8A2C4CA5C88c3F6B760761dBF28

✨ Query completed successfully!
```

### Query Resolver Info

Query the resolver metadata:

```bash
npm run query-info

# Or
node scripts/query-ens.js info
```

### Custom RPC URL

Set a custom Sepolia RPC URL:

```bash
export SEPOLIA_RPC_URL="https://sepolia.infura.io/v3/YOUR-PROJECT-ID"
npm run query-ens
```

## Features

- ✅ Resolves ENS names using viem
- ✅ Queries text records from CCResolver
- ✅ Parses YAML output
- ✅ Decodes ERC-7930 Interoperable Addresses
- ✅ Displays readable addresses and timestamps
- ✅ Provides Etherscan links for verification
- ✅ Error handling with helpful messages
- ✅ Lightweight and fast (viem vs ethers)

## Files

- **`query-ens.js`** - Main query script
- **`package.json`** - Dependencies (viem, js-yaml)
- **`README.md`** - This file

## Requirements

- Node.js >= 18.0.0
- Internet connection (queries Sepolia testnet)

## Live Deployment

This script queries the live CCResolver v0.1.0 deployment:

- **ENS Name**: `controlled-accounts.ecs.eth`
- **Resolver**: `0xAE5A879A021982B65A691dFdcE83528e8e13dFd3`
- **Network**: Ethereum Sepolia
- **Example ID**: 0 (live controlled accounts with 2 children)

## Help

```bash
node scripts/query-ens.js --help
```

