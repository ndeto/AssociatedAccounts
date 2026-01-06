# Agent Delegations Hook Reference

This repository implements a complete **ECS + ENS Hook** flow for the Agent Delegations credential type built on top of **ERC‑8092 Associated Accounts**.

The goal is to provide a repeatable pattern where:

1. An ENS profile publishes a Hook text record pointing to a resolver.
2. The resolver indexes pre-existing ERC‑8092 delegations from an `AssociationsStore`.
3. Clients discover the Hook, resolve it via ECS, and obtain a deterministic response envelope plus the raw credential payload.

## Repository layout

| Path | Purpose |
| ---- | ------- |
| `src/AgentDelegationsResolver.sol` | Onchain resolver that indexes Agent Delegation SARs and serves them through ENS text/data selectors. |
| `docs/pattern.md` | Pattern description covering hook grammar, request/response semantics, and flow diagrams. |
| `examples/agent-delegations/resolveHook.ts` | TypeScript helper that demonstrates hook discovery → resolver calls (text + data). |
| `offchain-resolver/server.ts` | Minimal HTTP server illustrating how an offchain resolver could respond with the same envelope schema. |
| `script/DeployAgentDelegationsResolver.s.sol` | Foundry deployment script for the resolver. |

## Hook format

- **ENS text record key**: configurable, defaults to `eth.ecs.agent-delegations:`
- **Hook grammar**:

  ```
  hook("text(0x<namehash>,'eth.ecs.agent-delegations:0x<associationId>')",0x<ResolverAddress>)
  ```

  - `associationId` is the ERC‑8092 association ID (32 bytes, hex).

## Resolver outputs

- `text(node, key)` → JSON envelope string:

  ```json
  {
    "version": 1,
    "associationId": "0x…",
    "delegator": "0x…",
    "agent": "0x…",
    "payloadLen": 123,
    "payloadHash": "0x…",
    "payloadHex": "0x…"
  }
  ```

- `data(node, key)` → raw `bytes` returned as `0x…` hex (identical to `payloadHex`).

The resolver validates the ERC‑8092 record (signatures, timestamps, interface ID) **at query time** using `AssociationsStore`. If validation fails, it returns an empty string/bytes to remain ENS compatible.

## Getting started

```bash
pnpm install   # or npm install
forge test --match-contract AgentDelegationsResolverTest
```

Run the hook resolution helper (requires an RPC URL and either an ENS name with a Hook or a literal Hook string):

```bash
RPC_URL=https://sepolia.example \
HOOK_VALUE='hook("text(0x...,''eth.ecs.agent-delegations:0x...'')",0xResolver)' \
npm run example:agent-delegations
```

Use the offchain resolver stub (optional) to mock an HTTP target:

```bash
npm run offchain:server
```

## Deploying the resolver

```bash
cd /Users/ndeto/ECS
forge script script/DeployAgentDelegationsResolver.s.sol:DeployAgentDelegationsResolver \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast
```

Environment variables consumed by the script:

| Name | Description |
| ---- | ----------- |
| `DEPLOYER_PRIVATE_KEY` | Hex private key used for broadcast. |
| `ASSOCIATIONS_STORE_ADDRESS` | Address of the ERC‑8092 AssociationsStore containing SARs. |
| `TEXT_RECORD_PREFIX` | Optional override for the resolver’s ENS key prefix (defaults to `eth.ecs.agent-delegations:`). |

## Additional documentation

See `docs/pattern.md` for a detailed walkthrough of the ENS hook grammar, ECS flow, and resolver response schemas. The TypeScript example illustrates how to parse hooks, query the resolver via ECS, and verify the returned payload hash.
