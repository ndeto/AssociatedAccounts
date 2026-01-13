# Resolver-Based Discovery of Agent Delegation Credentials

An implementation of ERC-8092 Agent Delegations using ENS and ECS

This repository implements a resolver-based discovery pattern for **Agent Delegation credentials**, providing a concrete implementation of the Agent Delegations ERC built on top of [ERC-8092 Associated Accounts](https://ethereum-magicians.org/t/erc-8092-associated-accounts/26858) and surfaced through ENS and ECS.

Specification (draft): [Agent Delegations](https://github.com/nxt3d/ERCs/blob/agent-delegations/ERCS/erc-agent-delegations.md) Authored by Prem Makeig (premm.eth).

## Why ENS

ENS is used as the identity anchor and discovery surface.

An ENS name represents a stable, decentralized identity that both humans and agents can resolve. ENS already exposes native extensibility via text records and resolver logic, which makes it a natural place to publish delegation credentials without introducing new registries or discovery layers.

This implementation leverages:

- **ENS Hooks** ([ERC-8121](https://ethereum-magicians.org/t/erc-8121-delegated-metadata-resolution-via-hooks/27424)) as the native mechanism to point from an identity to a resolver
- **ECS** ([ecs.vision](https://ecs.vision)) as the standardized resolution flow that interprets hooks, routes requests, and adds a security layer
- **Resolvers** ([ENS resolver spec](https://docs.ens.domains/ensip/1#resolver-specification)) as the execution layer that extracts and validates delegation credentials

ENS acts as the identity anchor. Delegation credentials are resolved via standard ENS resolver primitives, while ECS handles routing, execution of the hook, and security guarantees.

## Problem

In the agentic web, agents are first-class actors that must independently discover and verify delegated authority without relying on implicit trust or off-chain coordination.

This repository demonstrates a trustless, cryptographically provable mechanism for agent delegation discovery. Using ERC-8092 associations and the Agent Delegations ERC, agents can resolve, verify, and interpret delegated authority directly from an ENS-anchored identity, without relying on off-chain coordination or bespoke registries.

## What this repository provides

A repeatable pattern where:

1. A **custom credential resolver** is deployed that implements standard ENS resolver primitives (e.g. `text(bytes32,string` and `data(bytes32,string)`) and resolves delegation credentials.
2. An ENS profile publishes a Hook text record (per ERC-8121) that points to the resolver and specifies the credential query.
3. Clients discover the Hook, resolve it via ECS, and invoke the resolver using standard ENS calls.
4. The resolver validates and serves the underlying ERC-8092 Agent Delegation record(s) (query-time verification), returning a deterministic response envelope plus the raw credential payload.                                                                |

## Start here

[`docs/pattern.md`]('docs/pattern.md') is the core of this repo and the demo — it defines the hook grammar, resolver flow, and response schema that everything else implements.

- `src/AgentDelegationsResolver.sol` - custom resolver that maps, validates, and returns agent delegation credentials from the ERC-8092 registry.
- `agent-delegations/examples/agent-delegations/resolveHook.ts` is the minimal hook → resolver flow.
- `agent-delegations/examples/agent-delegations-ecs/test-ecs.ts` shows the ECS-backed resolution path.
- `agent-delegations/offchain-resolver` contains the offchain gateway implementation.

## Run examples

From the repo root, populate env files once and run the commands without inline vars:

- `./.env` for repo-wide examples (RPC_URL, SEPOLIA_RPC_URL, HOOK_VALUE, ECS_GATEWAY_URL)
- `./agent-delegations/offchain-resolver/.env.local` for the gateway
- `./agent-delegations/offchain-resolver/.vercel/.env.*.local` for Vercel builds (copied by `vercel pull`)

Install dependencies:

```bash
npm install
```

```bash
npm run example:agent-delegations
```

```bash
npm run example:agent-delegations-ecs
```
