# Pattern: Hook-Based Metadata Resolution

This document defines a hook-based resolution pattern for delegating metadata reads to a resolver contract. It uses [ERC-8121 hooks](https://ethereum-magicians.org/t/erc-8121-delegated-metadata-resolution-via-hooks/27424), ENS resolver primitives, and [ERC-3668 CCIP-Read](https://eips.ethereum.org/EIPS/eip-3668) when offchain data is required.

## Terminology

- **Record**: A domain-specific text value resolved by the target resolver, queried by a key (this pattern uses text records only).
- **Hook**: An ERC-8121 text-record redirection of the resolution logic to where the credential resolver lives.
- **Resolver**: A contract that implements ENS `text()` and returns the Record defined above.
- **Gateway**: An ERC-3668 HTTP endpoint that fetches offchain or cross-chain data and returns ABI-encoded results.

## Hook Record

The hook is stored as an ENS text record on an identity (i.e `parent-agent.eth`) name. The hook key is application-defined and scoped to the resolver’s application.

Example hook key used by the agent-delegations resolver:

```
eth.ecs.agent-delegations.delegates
```

Hook value format (string hook):

```
hook("text(0x<namehash>,'<record-prefix>:<record-id>')",0x<resolver>)
```

Where:

- `<namehash>` is the ENS namehash of the target name.
- `<record-prefix>` is the application-defined key namespace used by the resolver (example: `eth.ecs.agent-delegations`).
- `<record-id>` is the record identifier (hex or numeric, per the application).
- `<resolver>` is the L1 resolver address.

## Resolver Inputs

The resolver consumes a text/data key with an application-defined prefix and a record identifier suffix:

```
<record-prefix>:<record-id>
```

Example text record call:

```
text(node, "eth.ecs.agent-delegations:0x<delegationId>")
```

## Resolver Outputs

The resolver returns:

- `text(node, key)` → arbitrary payload string (JSON for this resolver).

The resolver contains the application-specific logic to retrieve credentials (onchain or offchain) and perform any required validation. For this resolver, the JSON payload follows the Agent Delegations spec and mirrors the [ERC-8004 registry schema](https://eips.ethereum.org/EIPS/eip-8004). Examples include the agent-delegations resolver in this repo and the controlled-accounts resolver demo: https://github.com/ndeto/AssociatedAccounts/tree/controlled-accounts-demo

The resolver returns an empty string if validation fails.

## Resolver Envelope (example)

The envelope is deterministic and may include a payload hash for integrity checks. The payload schema is application-defined.

```json
{
  "version": 1,
  "delegationId": "0x...",
  "delegator": "0x...",
  "agent": "0x...",
  "payloadLen": 123,
  "payloadHash": "0x...",
  "payloadHex": "0x..."
}
```

## Resolver Logic

The resolver validates:

- The record exists in the underlying data source (onchain or offchain), e.g. a store on Base Sepolia.
- Signatures and validity windows (if used) are enforced.
- The record format matches the expected interface ID (if applicable).

If any check fails, the resolver returns an empty string to remain ENS compatible.

## Offchain Resolution (ERC-3668)

When the data source lives offchain or on another network, the resolver uses ERC-3668:

1. Resolver emits `OffchainLookup`.
2. Gateway reads the L2 store.
3. Gateway returns ABI-encoded envelope data to the resolver callback.
4. Resolver returns the envelope to the caller.

For demo simplicity, this repo uses a custom offchain resolver. For production-grade gateways, use Unruggable Gateways: https://gateway-docs.unruggable.com/

## ECS Resolution

[ECS](https://ecs.vision) can interpret the hook, apply resolver trust checks, and invoke the resolver. This follows the same hook and resolver semantics, with ECS acting as the router and policy layer.

## Next steps

Explore the concrete agent-delegations implementation in [agent-delegations/README.md](../../agent-delegations/README.md).
