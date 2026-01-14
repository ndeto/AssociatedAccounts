## Agent Delegations Resolver Demo

This specification-level implementation shows how [ERC-8092](https://ethereum-magicians.org/t/erc-8092-associated-accounts/26858) and the proposed [Agent Delegations ERC](https://github.com/nxt3d/ERCs/blob/agent-delegations/ERCS/erc-agent-delegations.md) (interface ID `0xa9ce26a1`) can expose delegated agent relationships through ENS. For broader context, see the [main repository README](../README.md) and the [pattern guide](../docs/pattern/README.md).

In short:

- Stores signed ERC‑8092 associations.
- Indexes delegations by registering them in the ENS resolver (single or batch).
- Serves deterministic delegation payloads over `text()`/`resolve()`.

### Components

- **`src/AgentDelegationsResolver.sol`**
  - Base Sepolia resolver that reads `AssociationsStore` and returns deterministic payloads via `text()`/`resolve()`.
  - Behavior follows the Agent Delegations ERC specification (see link above).

- **`src/AgentDelegationsOffchainResolver.sol`**
  - L1 (Sepolia) resolver that emits ERC‑3668 `OffchainLookup` and delegates resolution to Base Sepolia.

### Layered flow

- **ENS Hook**: points to the L1 offchain resolver and the `eth.ecs.agent-delegations:<delegationId>` key.
- **L1 offchain resolver (Sepolia)**: `AgentDelegationsOffchainResolver` emits `OffchainLookup`.
- **CCIP‑Read gateway (HTTP)**: `agent-delegations/offchain-resolver` bridges L1 → Base Sepolia.
- **L2 resolver (Base Sepolia)**: `AgentDelegationsResolver` reads `AssociationsStore` and returns the payload to the gateway.

### Demo Flow

1. **Write flow (setup)**
   - Run `script/RegisterAgentDelegationsExample.s.sol` to:
     - Store SARs in `AssociationsStore` (`initiator` = delegator, `approver` = agent, `interfaceId = 0xa9ce26a1`).
     - Register the same agent list on `AgentDelegationsResolver` via `registerDelegation(bytes delegator, bytes[] agents)`.
   - The script prints the ERC‑8092 association IDs and the resolver-level `delegationId` values used in text record keys.
   - Publish the ENS Hook text record that points to the resolver and `eth.ecs.agent-delegations:<delegationId>`.

2. **Resolve via ENS**

   The diagram below illustrates the resolve flow:

<p align="center">
  <img width="50%" src="img/demoFlow.svg" alt="Agent delegations demo flow">
</p>

2. **Resolve via ENS**
   - An autonomous agent queries the ENS name.
   - ENS returns the Hook text record value, e.g. `hook("text(0x<namehash>,'eth.ecs.agent-delegations:<delegationId>')",0x<resolver>)`.
   - The hook resolves to the L1 offchain resolver (`AgentDelegationsOffchainResolver`) and calls `text()`.
   - The L1 resolver triggers `OffchainLookup` (ERC‑3668) to the HTTP gateway.
   - The gateway calls the Base Sepolia `AgentDelegationsResolver`, which reads `AssociationsStore`.
   - The gateway returns ABI‑encoded payload data to the L1 resolver.
   - The L1 resolver returns the delegation payload to the agent.

   The final `text(node, "eth.ecs.agent-delegations:0x<delegationId>")` (or ENS `resolve()`) call yields a JSON payload similar to:
   ```json
   {
     "version": 1,
     "delegationId": "0x...",
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
         },
         {
           "name": "ENS",
           "endpoint": "delegated-agent.eth"
         }
       ]
     }
   }
   ```

This demonstrates how agents can resolve and verify delegation credentials defined by ERC-8092 and its extensions from an ENS identity using ECS.

### Examples

Detailed example walkthroughs live in [agent-delegations/examples/README.md](./examples/README.md).
