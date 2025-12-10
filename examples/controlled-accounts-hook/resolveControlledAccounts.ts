import { createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'

// Minimal ABI for ENS text(bytes32,string)
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

export type ControlledAccountsResolution = {
  yaml: string
  resolver: `0x${string}`
}

export type ParsedHook = {
  resolver: `0x${string}`
  node: `0x${string}`
  credentialKey: string
}

/**
 * Parse and validate a canonical controlled-accounts Hook value.
 *
 * Expected format:
 *   hook("text(0x<64-hex>,'eth.ecs.controlled-accounts:<id>')",0x<40-hex>)
 */
export function parseHook(hookValue: string): ParsedHook {
  const trimmed = hookValue.trim()

  if (!trimmed.startsWith('hook(')) {
    throw new Error(`Text record is not a hook(): ${hookValue}`)
  }

  // Match: hook("fnSpec", 0xResolver)
  //  - capture group 1: inner function spec string (fnSpec)
  //  - capture group 2: resolver address
  const hookMatch = trimmed.match(
    /^hook\(\s*"([^"]+)"\s*,\s*(0x[0-9a-fA-F]{40})\s*\)\s*$/,
  )
  if (!hookMatch) {
    throw new Error(`Unsupported hook format: ${hookValue}`)
  }

  const [, fnSpec, resolverAddrRaw] = hookMatch
  const resolver = resolverAddrRaw as `0x${string}`

  // Extract credential key inside the first pair of single quotes in fnSpec:
  //   text(0x<node>,'<credentialKey>')
  const keyMatch = fnSpec.match(/'([^']+)'/)
  if (!keyMatch) {
    throw new Error(
      `Could not parse credential key from hook function spec: ${fnSpec}`,
    )
  }
  const credentialKey = keyMatch[1]

  // Extract node (namehash) inside text(...):
  //   text(0x<64-hex>, '...')
  const nodeMatch = fnSpec.match(/text\((0x[0-9a-fA-F]{64})/)
  if (!nodeMatch) {
    throw new Error(`Could not parse node from hook function spec: ${fnSpec}`)
  }
  const node = nodeMatch[1] as `0x${string}`

  return { resolver, node, credentialKey }
}

/**
 * Resolve controlled accounts for an ENS profile using a Hook that points to a CCResolver.
 *
 * hook(
 *   "text(0x<namehash(profileName)>,'eth.ecs.controlled-accounts:<id>')",
 *   0x<CCResolverAddress>
 * )
 *
 * The CCResolver implements text(node, "eth.ecs.controlled-accounts:<id>") where `<id>`
 * is the ERC‑8092 association id, and returns an ERC‑8092 response describing
 * the parent + delegate accounts for that association.
 */
export async function resolveControlledAccounts(params: {
  profileName: string
  rpcUrl: string
  hookKey?: string
}): Promise<ControlledAccountsResolution> {
  const { profileName, rpcUrl, hookKey = 'eth.ecs.controlled-accounts.delegates' } = params

  const client = createPublicClient({
    chain: sepolia,
    transport: http(rpcUrl),
  })

  // 1. Read the Hook from the profile resolver
  const hookValue = await client.getEnsText({
    name: profileName,
    key: hookKey,
  })

  if (!hookValue) {
    throw new Error(`No hook text record set for key "${hookKey}" on ${profileName}`)
  }

  // 2. Parse the Hook into resolver/node/credentialKey
  const { resolver, node, credentialKey } = parseHook(hookValue)

  // 3. Call resolver.text(node, key) directly on CCResolver in the Sepolia deployment.
  const yaml = await client.readContract({
    address: resolver,
    abi: TEXT_ABI,
    functionName: 'text',
    args: [node, credentialKey],
  })

  return {
    yaml: yaml as string,
    resolver,
  }
}
