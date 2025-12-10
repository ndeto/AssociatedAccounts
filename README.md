## Associated Accounts

This specification defines a standard for establishing and verifying associations between accounts. This allows addresses to publicly declare and prove a relationship with other addresses, enabling use cases like sub-account identity inheritance, authorization delegation, and reputation collation. 

This repo implements:

- **`AssociatedAccounts`** - The core interface defining the structs (`AssociatedAccountRecord` and `SignedAssociationRecord`), events, and storage functions for the ERC-8092 standard
- **`AssociatedAccountsLib`** - A helper library providing validation, EIP-712 hashing, and signature verification utilities for Associated Account records
- **`AssociationsStore`** - A reference implementation of an onchain storage contract for managing associations with features like account lookup, active association filtering, and revocation
- **`CCResolver`** - A full ENS Extended Resolver with controlled accounts verification, plus support for text, data, addr, and contenthash records 

## Deployments

### Ethereum Sepolia (Testnet)

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

## Development

### Build

```shell
forge build
```

### Test

```shell
# Solidity tests
forge test

# ENS integration test (JavaScript)
npm install
npm run query-ens      # Query controlled accounts ID 0
npm run query-info     # Query resolver-info metadata
```

### Format

```shell
forge fmt
```

## ENS Integration Example

Query the live `controlled-accounts.ecs.eth` deployment on Sepolia:

```bash
npm run query-ens
```

This demonstrates:
- ✅ ENS name resolution using viem
- ✅ Querying text records from CCResolver
- ✅ Parsing YAML output
- ✅ Decoding ERC-7930 addresses
- ✅ Live verification of controlled accounts

See [`scripts/README.md`](./scripts/README.md) for more details.
