# Resolver-Based Discovery of Agent Delegation Credentials

An implementation of the Agent Delegations ERC draft authored by Prem Makeig (`<premm.eth>`) using ENS and Ethereum Credential Service ([ECS](ecs.vision)).

It builds on top of [ERC-8092 Associated Accounts](https://ethereum-magicians.org/t/erc-8092-associated-accounts/26858).

Specification (draft): [Agent Delegations](https://github.com/nxt3d/ERCs/blob/agent-delegations/ERCS/erc-agent-delegations.md).

## Why ENS

ENS is the identity anchor and discovery surface, and it already exposes native multichain extensibility via text records and resolver logic.

This implementation leverages:

- **ENS Hooks** ([ERC-8121](https://ethereum-magicians.org/t/erc-8121-delegated-metadata-resolution-via-hooks/27424)) as the native mechanism to point from an identity to a resolver
- **ECS** as the standardized resolution flow that interprets hooks, routes requests, and adds a security layer
- **Resolvers** ([ENS resolver spec](https://docs.ens.domains/ensip/1#resolver-specification)) as the execution layer that extracts and validates delegation credentials

ENS acts as the identity anchor. Delegation credentials are resolved via standard ENS resolver primitives, while ECS handles routing, execution of the hook, and security guarantees.

## Problem

In the agentic web, trutsless agents are first-class actors that must independently discover and verify delegated authority without relying on implicit trust or off-chain coordination.

This repository demonstrates a cryptographically provable mechanism for agent delegation discovery. Using ERC-8092 associations and the Agent Delegations ERC, agents can trustlessly resolve, verify, and interpret delegated authority directly from an ENS-anchored identity.

## What this repository provides

A repeatable pattern where:

1. A **custom credential resolver** is deployed that implements standard ENS resolver primitives (e.g. `text(bytes32,string` and `data(bytes32,string)`).
   It performs the internal credential resolution, which in this repository is the Agent Delegations credential.
2. An ENS profile publishes a Hook text record (per ERC-8121) that points to the resolver and specifies the credential query.
3. Clients discover the Hook, resolve it via ECS, and invoke the resolver using standard ENS calls.
4. The resolver validates the ERC‑8092 Agent Delegation records and returns a deterministic envelope plus the raw payload.

## Start here

[`docs/pattern`](docs/pattern/) is the core of this repo and the demo — it defines the hook grammar, resolver flow, and response schema that everything else implements.

To run the ECS example:

```bash
npm install
npm run example:agent-delegations-ecs
```

| Path | Purpose |
| --- | --- |
| `src/AgentDelegationsResolver.sol` | Custom resolver that indexes, validates, and returns agent delegation credentials from the ERC-8092 registry. |
| `agent-delegations/examples/agent-delegations/resolveHook.ts` | Minimal hook → resolver flow. |
| `agent-delegations/examples/agent-delegations-ecs/test-ecs.ts` | ECS-backed resolution path with trust and security checks. |
| `agent-delegations/offchain-resolver` | Custom offchain gateway implementation used in this demo. |

## Deployments

| Name | Contract |
| --- | --- |
| Sepolia offchain resolver | [0xB776A62E60674940241038d4Bc63f617295ee462](https://sepolia.etherscan.io/address/0xB776A62E60674940241038d4Bc63f617295ee462) |
| Base Sepolia agent delegations resolver | [0xCA8076C532961a82bA25c1E238e21D009Fb9A670](https://sepolia.basescan.org/address/0xCA8076C532961a82bA25c1E238e21D009Fb9A670) |
| Base Sepolia Associations Store | [0x53329F6aab47Ee6267E3593721925f12dC933BF1](https://sepolia.basescan.org/address/0x53329F6aab47Ee6267E3593721925f12dC933BF1) |
