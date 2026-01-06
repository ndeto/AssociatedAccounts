import { createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'

const TEXT_ABI = [
  {
    type: 'function',
    name: 'text',
    stateMutability: 'view',
    inputs: [
      { name: 'node', type: 'bytes32' },
      { name: 'key', type: 'string' },
    ],
    outputs: [{ name: 'value', type: 'string' }],
  },
] as const

type ParsedHook = {
  node: `0x${string}`
  credentialKey: string
  resolver: `0x${string}`
}

function parseHook(value: string): ParsedHook {
  const trimmed = value.trim()
  const hookRegex =
    /^hook\(\s*"text\((0x[0-9a-fA-F]{64}),'(eth\.ecs\.agent-delegations:0x[0-9a-fA-F]{64})'\)"\s*,\s*(0x[0-9a-fA-F]{40})\s*\)$/

  const match = trimmed.match(hookRegex)
  if (!match) {
    throw new Error(`Unsupported hook format: ${value}`)
  }

  return {
    node: match[1] as `0x${string}`,
    credentialKey: match[2],
    resolver: match[3] as `0x${string}`,
  }
}

async function main() {
  const ensName = process.env.ENS_NAME
  const fallbackHook = process.env.HOOK_VALUE
  const hookKey = process.env.HOOK_KEY ?? 'eth.ecs.agent-delegations.delegates'
  const rpcUrl = process.env.RPC_URL

  if (!rpcUrl) {
    throw new Error('RPC_URL environment variable is required')
  }

  const client = createPublicClient({
    chain: sepolia,
    transport: http(rpcUrl),
  })

  let hookValue: string | null = null

  if (ensName) {
    hookValue = await client.getEnsText({ name: ensName, key: hookKey })
  }

  if (!hookValue) {
    if (!fallbackHook) {
      throw new Error(
        'Hook text record not found. Set ENS_NAME with a published hook or provide HOOK_VALUE directly.',
      )
    }
    hookValue = fallbackHook
  }

  const { node, credentialKey, resolver } = parseHook(hookValue)

  console.log('Hook parsed:')
  console.log('  Resolver:', resolver)
  console.log('  Credential key:', credentialKey)
  console.log('  Node:', node)

  const payload = await client.readContract({
    address: resolver,
    abi: TEXT_ABI,
    functionName: 'text',
    args: [node, credentialKey],
  })

  console.log('\nRaw resolver response:')
  console.log(payload)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
