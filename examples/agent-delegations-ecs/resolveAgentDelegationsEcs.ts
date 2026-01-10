import {
  createECSClient,
  getResolverAge,
  getResolverInfo,
  resolveCredential,
  sepolia,
} from "/Users/ndeto/unruggable/ecsjs/src/index";

export type AgentDelegationEntry = {
  associationId: string;
  agent: string;
  payloadLen: number;
  payloadHash: string;
  payloadHex: string;
};

export type AgentDelegationEnvelope = {
  version: number;
  delegationId: number;
  delegator: string;
  registeredAt: number;
  delegations: AgentDelegationEntry[];
};

export type AgentDelegationsEcsResolution = {
  resolver: `0x${string}`;
  label: string;
  ensName: string;
  ageInDays: number;
  review: string;
  credentialKey: string;
  envelope: AgentDelegationEnvelope;
  rawResponse: string;
};

export type ParsedGenericTextHook = {
  resolver: `0x${string}`;
  credentialKey: string;
  delegationId: number | null;
};

export function parseGenericTextHook(hookValue: string): ParsedGenericTextHook {
  const trimmed = hookValue.trim();

  if (!trimmed.startsWith("hook(")) {
    throw new Error(`Text record is not a hook(): ${hookValue}`);
  }

  const match = trimmed.match(
    /^hook\(\s*"text\((0x[0-9a-fA-F]{64}),'([^']+)'\)"\s*,\s*(0x[0-9a-fA-F]{40})\s*\)\s*$/
  );
  if (!match) {
    throw new Error(`Unsupported ECS hook format: ${hookValue}`);
  }

  const credentialKey = match[2];
  const resolverAddrRaw = match[3] as string;
  const resolver = resolverAddrRaw as `0x${string}`;

  const delegationId = parseDelegationIdFromKey(credentialKey);

  return { resolver, credentialKey, delegationId };
}

/**
 * Resolve an agent delegation credential via ECS:
 *
 * 1. Read a hook text record on the ENS profile resolver.
 * 2. Use ECS to fetch resolver metadata (label, age, review).
 * 3. Resolve the credential key `eth.ecs.agent-delegations:<delegationId>`
 *    from the advertised resolver.
 * 4. Parse and return the delegation envelope JSON.
 */
export async function resolveAgentDelegationViaEcs(params: {
  profileName: string;
  delegationId?: number;
  rpcUrl: string;
  hookKey?: string;
  expectedLabel?: string;
  minResolverAgeDays?: number;
}): Promise<AgentDelegationsEcsResolution> {
  const {
    profileName,
    delegationId,
    rpcUrl,
    hookKey = "eth.ecs.agent-delegations.delegates",
    expectedLabel = "agent-delegations",
    minResolverAgeDays = 0,
  } = params;

  const client = createECSClient({
    chain: sepolia,
    rpcUrl,
  });

  const hookValue = await client.getEnsText({
    name: profileName,
    key: hookKey,
  });

  if (!hookValue) {
    throw new Error(
      `No ECS hook text record set for key "${hookKey}" on ${profileName}`
    );
  }

  const {
    resolver,
    credentialKey,
    delegationId: hookDelegationId,
  } = parseGenericTextHook(hookValue);

  const { label, resolverUpdated, review } = await getResolverInfo(
    client,
    resolver
  );
  const ageInDays = Math.floor(getResolverAge(resolverUpdated) / 86400);

  if (expectedLabel && label !== expectedLabel) {
    throw new Error(
      `Unexpected ECS label "${label}" for resolver ${resolver} (expected "${expectedLabel}")`
    );
  }

  if (minResolverAgeDays > 0 && ageInDays < minResolverAgeDays) {
    throw new Error(
      `ECS resolver "${label}.ecs.eth" (${resolver}) is too new: ${ageInDays} days old (minimum ${minResolverAgeDays} days required)`
    );
  }

  const ensName = `${label}.ecs.eth`;
  const resolvedDelegationId = delegationId ?? hookDelegationId;
  if (resolvedDelegationId === null || resolvedDelegationId === undefined) {
    throw new Error(
      `Hook does not include a delegation ID. Pass delegationId explicitly for ${profileName}.`
    );
  }
  const resolvedCredentialKey =
    delegationId === undefined
      ? credentialKey
      : `eth.ecs.agent-delegations:${delegationId}`;

  const resolved = await resolveCredential(
    client,
    resolver,
    resolvedCredentialKey,
  );
  if (!resolved) {
    throw new Error(
      `No credential found for key "${resolvedCredentialKey}" on ECS resolver "${ensName}" (${resolver})`
    );
  }

  let envelope: AgentDelegationEnvelope;
  try {
    envelope = JSON.parse(resolved) as AgentDelegationEnvelope;
  } catch (error) {
    throw new Error(
      `Failed to parse agent delegation envelope JSON from resolver ${resolver}: ${(error as Error).message}`
    );
  }

  return {
    resolver,
    label,
    ensName,
    ageInDays,
    review,
    credentialKey,
    envelope,
    rawResponse: resolved,
  };
}

function parseDelegationIdFromKey(key: string): number | null {
  const prefix = "eth.ecs.agent-delegations:";
  if (!key.startsWith(prefix)) return null;
  const suffix = key.slice(prefix.length);
  if (!suffix) return null;
  if (!/^\d+$/.test(suffix)) return null;
  return Number(suffix);
}
