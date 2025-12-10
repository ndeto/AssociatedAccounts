# Controlled Accounts Hook Example

This example shows how to resolve **ERC‑8092 controlled accounts** for an ENS profile using:

- [ENS Hooks](https://github.com/nxt3d/ensips/blob/hooks/ensips/hooks.md); and
- A `CCResolver` [implementation](https://github.com/nxt3d/AssociatedAccounts/tree/controlled-accounts-demo) that:
  - Reads associations from an `AssociationsStore` ([ERC‑8092](https://ethereum-magicians.org/t/erc-8092-associated-accounts/26858));
  - Enforces the signing rules; and
  - Returns a YAML payload describing the controlled accounts.

### Running this example

From the `AssociatedAccounts` repo root:

```sh
npm install
npm run example:controlled-accounts-hook
```

This runs `examples/controlled-accounts-hook/test-hook.ts` which:

- Requires a valid Sepolia RPC endpoint (edit the `rpcUrl` in `test-hook.ts`).
- Reads the `eth.ecs.controlled-accounts.delegates` Hook text record from the ENS profile resolver.
- Parses the Hook to recover:
  - the `node` (namehash) for the profile, and
  - the ERC‑8092 credential key (e.g. `eth.ecs.controlled-accounts:1`).
- Calls `text(node, key)` on the CCResolver and prints the returned YAML and resolver address.

## On‑chain setup (Sepolia example)

This example assumes the following on‑chain setup:

- `CCResolver` deployed on Sepolia at address:
  - `0xAE5A879A021982B65A691dFdcE83528e8e13dFd3`
- An `AssociationsStore` contract deployed, with `CCResolver` configured to read associations from it
- A controlled accounts set registered as **ID `1`** for a profile account `test-user.eth`.

On the profile `test-user.eth`, set the following Hook text record on its resolver:

- **Key on the profile resolver:**

  ```text
  eth.ecs.controlled-accounts.delegates
  ```

- **Value on the profile resolver (string-based Hook):**

  ```text
  hook("text(0x1c47e8962cdc72f81e30c1feb8e83ff7381bd09b6112397e4881e05aae201a56,'eth.ecs.controlled-accounts:1')",0xAE5A879A021982B65A691dFdcE83528e8e13dFd3)
  ```

Where:

- `0x1c47…1a56` is `namehash("test-user.eth")`.
- The inner key is exactly: `eth.ecs.controlled-accounts:1`.
- The resolver address is the `CCResolver` contract on Sepolia.

The `CCResolver` implements:

- `text(node, "eth.ecs.controlled-accounts:1") -> string`

and returns a YAML payload like:

```yaml
id: 0
registeredAt: 1765325040
parent: "0x0001000003aa36a7144d45cd7472f2c46e81734c561a2d0b4b66c8fefe"
children:
  - "0x0001000003aa36a714f935f966a073746a9ee0f6a685a41da23a64e1d1"
  - "0x0001000003aa36a714cc8d7b159eafa8a2c4ca5c88c3f6b760761dbf28"
```

where `parent` and `children` are ERC‑7930 interoperable addresses for the profile and its delegates.

## Client flow

Given a profile ENS name `profileName` (e.g. `test-user.eth`), the client:

1. Resolves the Hook text record:

   ```ts
   const hookKey = 'eth.ecs.controlled-accounts.delegates'
   const hookValue = await client.getEnsText({ name: profileName, key: hookKey })
   ```

2. Parses the Hook value:

   - Confirms it starts with `hook(`.
   - Extracts:
     - The inner function spec, e.g. `text(0x<namehash>,'eth.ecs.controlled-accounts:1')`
     - The resolver address, e.g. `0xAE5A…Fd3`.
   - Extracts the inner credential key, where the suffix after `eth.ecs.controlled-accounts:`  
     is the ERC‑8092 association id (e.g. `eth.ecs.controlled-accounts:1`).

3. Uses the `node` (namehash) encoded in the Hook as the first argument to `text(...)`.  

4. Calls the resolver’s `text` method:

   ```ts
   const yaml = await client.readContract({
     address: ccResolverAddress,
     abi: TEXT_ABI,
     functionName: 'text',
     args: [node, 'eth.ecs.controlled-accounts:1'],
   })
   ```

5. Interprets the YAML as the controlled account set for that profile (parent + children).

## Example helper (viem)

`resolveControlledAccounts.ts` contains a minimal viem helper:

```ts
import { resolveControlledAccounts } from './resolveControlledAccounts'

const { yaml, resolver } = await resolveControlledAccounts({
  profileName: 'test-user.eth',
  rpcUrl: process.env.SEPOLIA_RPC_URL!,
})

console.log('Controlled accounts YAML:\n', yaml)
console.log('Resolved via CCResolver:', resolver)
```
