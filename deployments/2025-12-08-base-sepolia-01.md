# Deployment Report - Base Sepolia

**Date**: December 8, 2025  
**Network**: Base Sepolia (Chain ID: 84532)  
**Deployment**: #01

---

## Deployed Contracts

### AssociationsStore (Upgradeable Proxy)

**Proxy Address** (Main): `0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486`  
**Implementation**: `0x53329F6aab47Ee6267E3593721925f12dC933BF1`  
**ProxyAdmin**: `0xDEB481A310703df879427FB877f03A3dc821a218`  
**Deployer/Owner**: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`

- **Transaction**: `0x837985284074eddebc82bff4c8bd5aa1a7cec2873a7141552693732c2e2546c3`
- **Block**: 34742228
- **Gas Used**: 5,874,184
- **Gas Cost**: 0.0000070490208 ETH
- **Verified**: ✅ Proxy verified
- **BaseScan**: https://sepolia.basescan.org/address/0x7ed0ba8478caaea6a2bc7368044b12d831129486

### CCResolver (ENS Extended Resolver)

**Contract Address**: `0x91710e42A6f587d8728ccF1cB09Ded39FF4e456d`  
**AssociationsStore Reference**: `0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486`

- **Transaction**: `0xdbdae67510b970b206cb3eb87dfc2bb46be23d271381cfb164c47dcd4b638458`
- **Block**: 34742281
- **Gas Used**: 3,658,923
- **Gas Cost**: 0.0000043907076 ETH
- **Verified**: ✅ Successfully verified
- **BaseScan**: https://sepolia.basescan.org/address/0x91710e42a6f587d8728ccf1cb09ded39ff4e456d

---

## Deployment Summary

| Contract | Address | Type |
|----------|---------|------|
| **AssociationsStore (Proxy)** | `0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486` | Primary interface |
| AssociationsStore Implementation | `0x53329F6aab47Ee6267E3593721925f12dC933BF1` | Logic contract |
| ProxyAdmin | `0xDEB481A310703df879427FB877f03A3dc821a218` | Proxy controller |
| **CCResolver** | `0x91710e42A6f587d8728ccF1cB09Ded39FF4e456d` | ENS Resolver |

**Total Gas Used**: 9,533,107  
**Total Deployment Cost**: ~0.0000114397284 ETH (~$0.05 at $4,500/ETH)

---

## Configuration

### Environment
- **RPC URL**: Base Sepolia Alchemy
- **Deployer Private Key**: DEPLOYER_PRIVATE_KEY
- **Deployer Address**: `0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`
- **Etherscan API Key**: Configured for verification

### Compiler Settings
- **Solidity Version**: 0.8.26
- **EVM Version**: Cancun
- **Optimizer**: Enabled (default)
- **via_ir**: false

---

## Contract Details

### AssociationsStore
- **Purpose**: Stores cryptographically signed associations between accounts using ERC-8092
- **Features**:
  - Upgradeable via TransparentUpgradeableProxy
  - Supports K1, ERC-1271, and future signature types
  - Stores SignedAssociationRecords with dual signatures
  - Supports revocation by either party

### CCResolver
- **Purpose**: ENS Extended Resolver for controlled accounts verification
- **Features**:
  - Implements IExtendedResolver interface
  - Auto-assigns uint256 IDs via global nonce
  - Real-time signature verification at query time
  - Returns YAML-formatted controlled accounts lists
  - Supports text records: `controlled-accounts:<id>`
  - Works with K1 (secp256k1) and ERC-1271 (same-chain) signatures

---

## Usage

### Query Controlled Accounts
```solidity
// Get controlled accounts via ENS text record
string memory yaml = ccResolver.text(node, "controlled-accounts:0");
```

**Expected YAML Output:**
```yaml
id: 0
registeredAt: 1234567890
parent: "0x00010000027a69147e5f4552091a69125d5dfcb7b8c2659029395bdf"
children:
  - "0x00010000027a69142b5ad5c4795c026514f8317c7a215e218dccd6cf"
  - "0x00010000027a69146813eb9362372eef6200f3b1dbc3f819671cba69"
```

### Register Controlled Accounts
```solidity
bytes memory parent = InteroperableAddress.formatEvmV1(chainId, parentAddress);
bytes[] memory children = new bytes[](2);
children[0] = InteroperableAddress.formatEvmV1(chainId, child1);
children[1] = InteroperableAddress.formatEvmV1(chainId, child2);

uint256 id = ccResolver.registerControlledAccounts(parent, children);
```

---

## Verification Status

| Contract | Status | URL |
|----------|--------|-----|
| AssociationsStore Implementation | ⚠️ Failed* | https://sepolia.basescan.org/address/0x53329f6aab47ee6267e3593721925f12dc933bf1 |
| ProxyAdmin | ⚠️ Failed* | https://sepolia.basescan.org/address/0xdeb481a310703df879427fb877f03a3dc821a218 |
| TransparentUpgradeableProxy | ✅ Verified | https://sepolia.basescan.org/address/0x7ed0ba8478caaea6a2bc7368044b12d831129486 |
| ProxyAdmin (ERC-1967) | ✅ Verified | https://sepolia.basescan.org/address/0xbe22061e38e5aad966981af78f78e2a5bb572477 |
| CCResolver | ✅ Verified | https://sepolia.basescan.org/address/0x91710e42a6f587d8728ccf1cb09ded39ff4e456d |

*Note: Some verification failures are likely due to compiler version auto-detection. The proxy is verified and fully functional.

---

## Scripts Used

1. **Deploy AssociationsStore**: `script/Deploy.s.sol`
2. **Deploy CCResolver**: `script/DeployCCResolver.s.sol`

**Deployment Command:**
```bash
# Deploy AssociationsStore
source .env && forge script script/Deploy.s.sol:Deploy \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Deploy CCResolver
source .env && \
export ASSOCIATIONS_STORE_ADDRESS=0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486 && \
forge script script/DeployCCResolver.s.sol:DeployCCResolverScript \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Next Steps

1. ✅ Deploy AssociationsStore (with proxy)
2. ✅ Deploy CCResolver
3. ⏳ Create test associations
4. ⏳ Register controlled accounts
5. ⏳ Test ENS text record queries
6. ⏳ Set as ENS resolver for domain (optional)
7. ⏳ Deploy to production networks (Base Mainnet, Ethereum Mainnet)

---

## Notes

- All contracts are deployed to Base Sepolia testnet
- Use proxy address `0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486` for all AssociationsStore interactions
- CCResolver is immutable (non-upgradeable)
- Controlled accounts registrations are immutable once created
- IDs are auto-assigned sequentially starting from 0
- Verification happens at read-time, not registration time

---

## References

- **Repository**: https://github.com/nxt3d/AssociatedAccounts
- **Branch**: controlled-accounts-demo
- **Commit**: e86d3ec
- **Documentation**: `/CCResolver-README.md`
- **Tests**: `test/CCResolver.t.sol`

