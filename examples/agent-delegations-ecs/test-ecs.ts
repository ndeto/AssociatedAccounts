import 'dotenv/config'
import { resolveAgentDelegationViaEcs } from './resolveAgentDelegationsEcs'
import { rpc } from 'viem/utils'

async function main() {
  // ENS profile name whose resolver stores the ECS hook text record
  const profileName = 'delegated-agent.eth'
  // Sepolia RPC endpoint used by ecsjs / viem
  const rpcUrl = process.env.SEPOLIA_RPC_URL

  if (!rpcUrl) {
    throw new Error('SEPOLIA_RPC_URL environment variable is required')
  }

  const result = await resolveAgentDelegationViaEcs({
    profileName,
    rpcUrl,
    // Example hardening flags:
    // expectedLabel: 'agent-delegations',
    // minResolverAgeDays: 30,
  })

  console.log('Agent delegation envelope JSON:')
  console.log(JSON.stringify(result.envelope, null, 2))
  console.log('\nDecoded payloads:')
  result.envelope.delegations.forEach((entry, idx) => {
    const decoded = Buffer.from(entry.payloadHex.slice(2), 'hex').toString('utf8')
    try {
      const payload = JSON.parse(decoded)
      console.log(`  [${idx}]`, payload)
    } catch {
      console.log(`  [${idx}]`, decoded)
    }
  })
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
