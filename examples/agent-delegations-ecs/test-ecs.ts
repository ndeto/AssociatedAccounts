import { resolveAgentDelegationViaEcs } from './resolveAgentDelegationsEcs'

async function main() {
  // ENS profile name whose resolver stores the ECS hook text record
  const profileName = 'agent-demo.eth'
  // Agent delegation associationId to resolve (bytes32 hex string)
  const associationId = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
  // Sepolia RPC endpoint used by ecsjs / viem
  const rpcUrl = process.env.RPC_URL ?? 'https://sepolia.infura.io/v3/YOUR_API_KEY'

  const result = await resolveAgentDelegationViaEcs({
    profileName,
    associationId,
    rpcUrl,
    // Example hardening flags:
    // expectedLabel: 'agent-delegations',
    // minResolverAgeDays: 30,
  })

  console.log('Agent delegation envelope JSON:')
  console.log(JSON.stringify(result.envelope, null, 2))
  console.log('\nResolved via ECS resolver:', result.resolver)
  console.log('ECS label:', result.label)
  console.log('ECS ENS name:', result.ensName)
  console.log('Resolver age (days):', result.ageInDays)
  console.log('Resolver review status:', result.review || 'None')
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
