## Agent Delegations Resolver Demo

This specification-level implementation shows how [ERC-8092](https://ethereum-magicians.org/t/erc-8092-associated-accounts/26858) and the proposed [Agent Delegations ERC](https://github.com/nxt3d/ERCs/blob/agent-delegations/ERCS/erc-agent-delegations.md) (interface ID `0xa9ce26a1`) can expose delegated agent relationships through ENS. For broader context, see the [main repository README](../README.md).

In short: it stores signed ERC‑8092 associations, registers them in an ENS resolver, and serves a deterministic delegation envelope over `text()`/`resolve()`.

### Components

- **`src/AgentDelegationsResolver.sol`**
  - ENS resolver implementation of the Agent Delegations ERC.
  - Validates ERC‑8092 SARs from `AssociationsStore` and returns deterministic envelopes via `text()`/`resolve()`.
  - Behavior follows the Agent Delegations ERC specification (see link above).

- **`script/DeployAgentDelegationsResolver.s.sol`**
  - Foundry script to deploy the resolver with:
    ```bash
    forge script script/DeployAgentDelegationsResolver.s.sol:DeployAgentDelegationsResolver \
      --rpc-url $SEPOLIA_RPC_URL \
      --broadcast
    ```
  - Requires `DEPLOYER_PRIVATE_KEY`, `ASSOCIATIONS_STORE_ADDRESS`, and optional `TEXT_RECORD_PREFIX`

### Layered flow

- **ENS Hook**: points to the L1 resolver and the `eth.ecs.agent-delegations:<id>` key so resolution can complete.
- **L1 ENS resolver (Sepolia)**: `AgentDelegationsResolver.sol` answers `text()`/`resolve()` and emits CCIP‑Read requests.
- **Offchain gateway (HTTP)**: `agent-delegations/offchain-resolver` bridges L1 → L2 via ERC‑3668 and returns the ABI‑encoded envelope.
- **L2 credential source (Base Sepolia)**: SARs are stored in `AssociationsStore` and mapped in the L1 resolver via `registerDelegation`.

### Demo Flow

1. **Write flow (setup)**
   - Run `script/RegisterAgentDelegationsExample.s.sol` to:
     - Store SARs in `AssociationsStore` (`initiator` = delegator, `approver` = agent, `interfaceId = 0xa9ce26a1`).
     - Register the same agent list on `AgentDelegationsResolver` via `registerDelegation(bytes delegator, bytes[] agents)`.
   - The script prints the ERC‑8092 `associationId` values and the ENS text record keys to query.
   - Publish the ENS Hook text record that points to the resolver and `eth.ecs.agent-delegations:<associationId>`.

2. **Resolve via ENS**

   The diagram below illustrates the resolve flow:

<p align="center">
  <img width="50%" src="img/demoFlow.svg" alt="Agent delegations demo flow">
</p>

2. **Resolve via ENS**
   - An autonomous agent queries the ENS name.
   - ENS returns the Hook text record value, e.g. `hook("text(0x<namehash>,'eth.ecs.agent-delegations:<delegation_id>')",0x<resolver>)`.
   - The hook resolves to the L1 ENS resolver (`AgentDelegationsResolver`) and calls `text()`.
   - The L1 resolver triggers `OffchainLookup` (ERC‑3668) to the HTTP gateway.
   - The gateway reads the L2 `AssociationsStore` on Base Sepolia.
   - The gateway returns ABI‑encoded envelope data to the L1 resolver.
   - The L1 resolver returns a verified delegation envelope to the agent.

   The final `text(node, "eth.ecs.agent-delegations:0x<associationId>")` (or ENS `resolve()`) call yields an envelope JSON similar to:
   ```json
   {
     "version": 1,
     "associationId": "0x...",
     "delegator": "0x...",
     "agent": "0x...",
     "payload": {
       "association": "Delegated Agent",
       "name": "Example Agent",
       "description": "Delegated assistant",
       "endpoints": [
         {
           "name": "A2A",
           "endpoint": "https://agent.example/.well-known/agent-card.json"
         }
       ]
     }
   }
   ```

This demonstrates how agents can resolve and verify delegation credentials defined by ERC-8092 and its extensions from an ENS identity using ECS.

### Offchain Resolver Example

For the ECS demo flow, the offchain resolver is required because the ERC‑8092 AssociationsStore lives on Base. The gateway bridges the L1 resolver query to Base via [ERC‑3668 CCIP‑Read](https://eips.ethereum.org/EIPS/eip-3668) and returns the ABI‑encoded delegation envelope. Start it with:

```bash
PORT=8787 npm run offchain:agent-delegations
```

Wire the URL into your L1 resolver’s `OffchainLookup` and the resolver will stream back the JSON payload.

For more detailed and standardized ERC‑3668 CCIP‑Read behavior, refer to Unruggable Gateways.

### Examples

Detailed example walkthroughs live in [agent-delegations/examples/README.md](./examples/README.md).
