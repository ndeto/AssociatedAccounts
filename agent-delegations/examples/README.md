# Agent Delegations Examples

This folder collects the runnable demos for the agent-delegations pattern. The scripts assume the repo-wide `.env` is populated (see `/.env.example`).

## Hook → Resolver (direct)

The `agent-delegations/examples/agent-delegations` flow demonstrates resolving a hook by calling the resolver directly.

Run from the repo root:

```bash
npm run example:agent-delegations
```

## ECS-backed Resolution

The `agent-delegations/examples/agent-delegations-ecs` flow mirrors the controlled-accounts ECS demo and shows how to:

1. Read the Hook text record on an ENS profile (`eth.ecs.agent-delegations.delegates`).
2. Use `@nxt3d/ecsjs` to trust-evaluate the resolver registered for the `agent-delegations` label.
3. Resolve the credential key `eth.ecs.agent-delegations:<delegationId>` by calling the resolver’s `text(node,key)` via ECS.

Run from the repo root:

```bash
npm run example:agent-delegations-ecs
```
