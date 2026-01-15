import 'dotenv/config'
import { resolveAgentDelegationViaEcs } from './resolveAgentDelegationsEcs'

async function main() {
  // ENS profile name whose resolver stores the ECS hook text record
  const profileName = 'delegated-agent.eth'
  // Sepolia RPC endpoint used by ecsjs / viem
  const rpcUrl = process.env.SEPOLIA_RPC_URL

  if (!rpcUrl) {
    throw new Error('SEPOLIA_RPC_URL environment variable is required')
  }

  console.log('ECS quickstart')
  console.log('  ENS profile:', profileName)
  console.log('  Hook key:', 'eth.ecs.agent-delegations.delegates')

  const result = await resolveAgentDelegationViaEcs({
    profileName,
    rpcUrl,
    // Example hardening flags:
    // expectedLabel: 'agent-delegations',
    // minResolverAgeDays: 30,
  })

  console.log('\nAgent delegation envelope JSON:')
  console.log(JSON.stringify(result.envelope, null, 2))
  console.log('\nDecoded payloads (payloadHex -> JSON):')
  result.envelope.delegations.forEach((entry, idx) => {
    const decoded = Buffer.from(entry.payloadHex.slice(2), 'hex').toString('utf8')
    try {
      const payload = JSON.parse(decoded)
      console.log(`  [${idx}]`, JSON.stringify(payload, null, 2))
    } catch {
      console.log(`  [${idx}]`, decoded)
    }
  })
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
