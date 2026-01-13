# Pattern: Hook-Based Metadata Resolution

This document defines a hook-based resolution pattern for delegating metadata reads to a resolver contract. It uses ERC-8121 hooks, ENS resolver primitives, and ERC-3668 CCIP-Read when offchain data is required.

## Terminology

- **Record**: A domain-specific data record resolved by the target resolver.
- **Record ID**: A `bytes32` identifier or key suffix used to target a specific record.
- **Hook**: An ERC-8121 text-record redirection to a resolver function.
- **Resolver**: A contract that implements ENS `text()` / `data()` and returns the resolved value.
- **Gateway**: An ERC-3668 HTTP endpoint that fetches offchain or cross-chain data and returns ABI-encoded results.

## Hook Record

The hook is stored as an ENS text record on an identity (profile) name. The hook key is application-defined.

```
eth.ecs.agent-delegations.delegates
```

Hook value format (string hook):

```
hook("text(0x<namehash>,'<record-prefix>:<record-id>')",0x<resolver>)
```

Where:
- `<namehash>` is the ENS namehash of the target name.
- `<record-id>` is the record identifier (hex or numeric, per the application).
- `<resolver>` is the L1 resolver address.

## Resolver Inputs

The resolver consumes a text/data key with an application-defined prefix and a record identifier suffix:

```
<record-prefix>:<record-id>
```

## Resolver Outputs

The resolver returns:

- `text(node, key)` → JSON envelope string (or plain string if the application chooses).
- `data(node, key)` → raw payload bytes.

The resolver contains the application-specific logic to retrieve credentials (onchain or offchain) and perform any required validation. Examples include the agent-delegations resolver in this repo and the controlled-accounts resolver demo: https://github.com/ndeto/AssociatedAccounts/tree/controlled-accounts-demo

Both functions return empty values if validation fails.

## Envelope Schema (example)

The envelope is deterministic and may include a payload hash for integrity checks. The payload schema is application-defined.

```json
{
  "version": 1,
  "recordId": "0x...",
  "subject": "0x...",
  "issuer": "0x...",
  "payloadLen": 123,
  "payloadHash": "0x...",
  "payloadHex": "0x..."
}
```

## Validation Rules

The resolver validates:

- The record exists in the underlying data source.
- Signatures and validity windows (if used) are enforced.
- The record format matches the expected interface ID (if applicable).

If any check fails, the resolver returns an empty string/bytes to remain ENS compatible.

## Offchain Resolution (ERC-3668)

When the data source lives offchain or on another network, the resolver uses ERC-3668:

1. Resolver emits `OffchainLookup`.
2. Gateway reads the L2 store.
3. Gateway returns ABI-encoded envelope data to the resolver callback.
4. Resolver returns the envelope to the caller.

## ECS Resolution

ECS can interpret the hook, apply resolver trust checks, and invoke the resolver. This follows the same hook and resolver semantics, with ECS acting as the router and policy layer.

## Security Considerations

- Treat the resolver as the trust anchor; restrict hook usage to known resolvers.
- Enforce an association interface ID to prevent payload confusion.
- Limit recursive hooks if a client supports nested resolution.
- Expect CCIP-Read to be disabled in some clients; hook resolution should fail closed in that case.

## Next steps

Explore the concrete agent-delegations implementation in [agent-delegations/README.md](../agent-delegations/README.md).
