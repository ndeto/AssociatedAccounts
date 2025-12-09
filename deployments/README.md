# Deployments

This directory contains deployment reports for all contract deployments across different networks.

## Naming Convention

Deployment reports follow the format:
```
YYYY-MM-DD-<network>-<sequence>.md
```

- **YYYY-MM-DD**: Deployment date
- **network**: Target network (e.g., base-sepolia, mainnet, base-mainnet)
- **sequence**: Deployment sequence number for that day (01, 02, etc.)

## Current Deployments

### Base Sepolia (Testnet)

| Date | Deployment | Contracts |
|------|-----------|-----------|
| 2025-12-08 | #01 | AssociationsStore (Proxy), CCResolver |

See: [2025-12-08-base-sepolia-01.md](./2025-12-08-base-sepolia-01.md)

### Ethereum Sepolia (Testnet)

| Date | Deployment | Contracts | Notes |
|------|-----------|-----------|-------|
| 2025-12-08 | #02 | AssociationsStore (Proxy), CCResolver | Initial deployment with example accounts |
| 2025-12-08 | #03 | CCResolver | Updatable prefix feature |
| 2025-12-09 | #04 | AssociationsStore, CCResolver v0.1.0 | ⭐ **LATEST** - Full ENS resolver |

See: 
- [2025-12-08-sepolia-02.md](./2025-12-08-sepolia-02.md) - Initial deployment with examples
- [2025-12-08-sepolia-03.md](./2025-12-08-sepolia-03.md) - Updatable prefix
- [2025-12-09-sepolia-04.md](./2025-12-09-sepolia-04.md) - Full ENS resolver v0.1.0

---

## Quick Reference

### Base Sepolia (Chain ID: 84532)

**AssociationsStore (Proxy)**: `0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486`  
**CCResolver**: `0x91710e42A6f587d8728ccF1cB09Ded39FF4e456d`

### Ethereum Sepolia (Chain ID: 11155111)

**AssociationsStore (Deployment #02)**: `0x44CcD9b079C4DEf953A6ec9fC7F63cDC0cb14F50` (Proxy)  
**AssociationsStore (Deployment #04)**: `0x658CC576192a9e950DCd1BFb0F77F1D75a055D49` ⭐ **LATEST**  
**CCResolver (Deployment #02)**: `0xdBB090B891297d515d064b0A7663caE116777f6E` (hardcoded prefix)  
**CCResolver (Deployment #03)**: `0xCE943F957FC46a8d048505E6949e32201a128f84` (updatable prefix)  
**CCResolver v0.1.0 (Deployment #04)**: `0xAE5A879A021982B65A691dFdcE83528e8e13dFd3` ⭐ **LATEST** (full ENS resolver)

---

## Production Deployments

Coming soon...

