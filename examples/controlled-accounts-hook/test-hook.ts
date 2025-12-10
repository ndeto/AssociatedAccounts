import { resolveControlledAccounts } from './resolveControlledAccounts'

async function main() {
  // ENS name whose resolver:
  //  - has the Hook text record set at `eth.ecs.controlled-accounts.delegates`
  //  - and whose Hook value points to a CCResolver that understands ERC‑8092
  const profileName = 'test-user.eth'

  // Sepolia RPC endpoint used by viem to:
  //  - read the Hook text record on the profile resolver
  //  - call CCResolver.text(node, credentialKey) to fetch the YAML
  const rpcUrl =
    'https://sepolia.infura.io/v3/_your_api_key'

  const result = await resolveControlledAccounts({ profileName, rpcUrl })
  console.log('Controlled accounts YAML:')
  process.stdout.write(result.yaml + '\n')
  console.log('Resolved via CCResolver:', result.resolver)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

