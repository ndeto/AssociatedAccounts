## Associated Accounts

This specification defines a standard for establishing and verifying associations between accounts. This allows addresses to publicly declare and prove a relationship with other addresses, enabling use cases like sub-account identity inheritance, authorization delegation, and reputation collation. 

This repo implements:

- **`AssociatedAccounts`** - The core interface defining the structs (`AssociatedAccountRecord` and `SignedAssociationRecord`), events, and storage functions for the ERC-8092 standard
- **`AssociatedAccountsLib`** - A helper library providing validation, EIP-712 hashing, and signature verification utilities for Associated Account records
- **`AssociationsStore`** - A reference implementation of an onchain storage contract for managing associations with features like account lookup, active association filtering, and revocation
- **`CCResolver`** - A full ENS Extended Resolver with controlled accounts verification, plus support for text, data, addr, and contenthash records 

## Deployments

### Ethereum Sepolia (Testnet) ⭐ LATEST

**CCResolver v0.1.0** - Full ENS Resolver with Controlled Accounts
- **Address**: [`0xAE5A879A021982B65A691dFdcE83528e8e13dFd3`](https://sepolia.etherscan.io/address/0xae5a879a021982b65a691dfdce83528e8e13dfd3)
- **Features**: Controlled accounts, text, data, addr, contenthash records
- **Status**: ✅ Live with example registrations
- **resolver-info**: Set and verified
- **Deployment**: December 9, 2025

**AssociationsStore**
- **Address**: [`0x658CC576192a9e950DCd1BFb0F77F1D75a055D49`](https://sepolia.etherscan.io/address/0x658cc576192a9e950dcd1bfb0f77f1d75a055d49)
- **Type**: Implementation (no proxy)
- **Status**: ✅ Verified

**Example Controlled Account:**
- Query: `eth.ecs.controlled-accounts:0`
- Parent: `0x4D45CD7472f2C46e81734c561a2D0b4B66C8FEFe`
- Children: 2 accounts (cryptographically verified)

See detailed deployment info: [`deployments/2025-12-09-sepolia-04.md`](./deployments/2025-12-09-sepolia-04.md)

---

### Base Sepolia (Testnet)

**AssociationsStore** - Deployed behind a Transparent Upgradeable Proxy

| Contract | Address | Link |
|----------|---------|------|
| **Proxy** | `0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486` | [View on BaseScan](https://sepolia.basescan.org/address/0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486) |
| Implementation | `0x3b01b5e85E2E146dD82fe83C3dF2C60D9Fd75d3B` | [View on BaseScan](https://sepolia.basescan.org/address/0x3b01b5e85E2E146dD82fe83C3dF2C60D9Fd75d3B) |
| ProxyAdmin | `0x0EE3f79a3f34d35Ac50Ae5F8F57e1E589a85bdC0` | [View on BaseScan](https://sepolia.basescan.org/address/0x0EE3f79a3f34d35Ac50Ae5F8F57e1E589a85bdC0) |

**CCResolver** (Controlled Accounts Only)
- **Address**: [`0x91710e42A6f587d8728ccF1cB09Ded39FF4e456d`](https://sepolia.basescan.org/address/0x91710e42a6f587d8728ccf1cb09ded39ff4e456d)

> **Note:** Always interact with the Proxy address. The implementation contract contains the logic, but the proxy maintains the state and is upgradeable.

See all deployments: [`deployments/README.md`](./deployments/README.md) 


## Documentation

The ERC draft can be found in this PR (will update to canonical link once merged):
https://github.com/ethereum/ERCs/pull/1377/files

## Installation

### As a Foundry dependency

```shell
forge install stevieraykatz/AssociatedAccounts
```

## Development

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```
