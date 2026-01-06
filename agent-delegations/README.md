## Agent Delegations Resolver Demo

This specification-level implementation shows how [ERC-8092](https://ethereum-magicians.org/t/erc-8092-associated-accounts/26858) and the proposed Agent Delegations ERC (interface ID `0xa9ce26a1`) can expose delegated agent relationships through ENS.

### Components

- **`src/AgentDelegationsResolver.sol`**
  - Permissionless `registerDelegation(bytes delegator, bytes[] agents)` resolves each pair’s association by fetching the ERC‑8092 SAR from `AssociationsStore`
  - Queries `AssociationsStore` for the signed association record between delegator and agent
  - Requires `interfaceId == 0xa9ce26a1`
  - Returns an envelope JSON string via `text()` or ENS `resolve()` where the `payload` field contains the raw SAR `data` blob (opaque to the resolver)
  - Uses the association ID (`eth.ecs.agent-delegations:0x<associationId>`) for resolver hooks while still providing helper views to enumerate delegations by delegator or by agent

- **`script/DeployAgentDelegationsResolver.s.sol`**
  - Foundry script to deploy the resolver with:
    ```bash
    forge script script/DeployAgentDelegationsResolver.s.sol:DeployAgentDelegationsResolver \
      --rpc-url $SEPOLIA_RPC_URL \
      --broadcast
    ```
  - Requires `DEPLOYER_PRIVATE_KEY`, `ASSOCIATIONS_STORE_ADDRESS`, and optional `TEXT_RECORD_PREFIX`

### Demo Flow

1. **Create a Delegated Agent SAR**
   - Store a SAR in `AssociationsStore` where:
     - `initiator` is the delegator (owner)
     - `approver` is the agent
     - `interfaceId = 0xa9ce26a1`
     - `data` contains the JSON payload defined by the Agent Delegations ERC, including `association`, `name`, `description`, and optional endpoints.

2. **Register Delegations**
   - Call `registerDelegation(bytes delegator, bytes[] agents)` on `AgentDelegationsResolver` to link the ENS resolver to existing ERC‑8092 records. Each returned ID is the ERC‑8092 associationId (bytes32).
   - Use `getDelegationIds(bytes delegator)` to enumerate the associationIds for a delegator.

3. **Resolve via ENS**
   - Query `text(node, "eth.ecs.agent-delegations:0x<associationId>")` (or ENS `resolve()`) to receive an envelope JSON similar to:
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

This demonstrates how ERC-8092’s cryptographic guarantees combine with the Agent Delegations ERC to publish verifiable agent delegations through ENS while deferring payload interpretation to offchain consumers. Consumers can navigate delegations via association IDs (bytes32) or the provided view helpers to list delegations by delegator or by agent.

### Offchain Resolver Example

`agent-delegations/offchain-resolver/server.ts` is a minimal HTTP target that emulates a CCIP-Read gateway. It accepts POST requests from an L1 offchain resolver and returns an ABI-encoded string containing the delegation envelope. Start it with:

```bash
PORT=8787 npm run offchain:agent-delegations
```

Wire the URL into your L1 resolver’s `OffchainLookup` and the resolver will stream back the JSON payload.

### ECS Example

The `examples/agent-delegations-ecs` folder mirrors the controlled-accounts ECS demo and shows how to:

1. Read the Hook text record on an ENS profile (`eth.ecs.agent-delegations.delegates`).
2. Use `@nxt3d/ecsjs` to trust-evaluate the resolver registered for the `agent-delegations` label.
3. Resolve the credential key `eth.ecs.agent-delegations:<delegationId>` by calling the resolver’s `text(node,key)` via ECS.

Run it with:

```bash
RPC_URL="https://sepolia.infura.io/v3/YOUR_KEY" npm run example:agent-delegations-ecs
```
