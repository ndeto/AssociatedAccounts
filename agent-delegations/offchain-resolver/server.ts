import http from 'node:http'

/**
 * Minimal offchain resolver target. It accepts CCIP-Read style POST requests
 * (sender + call data are opaque here) and always returns a static JSON payload
 * encoded as ABI `string`. Update the `sampleEnvelope` object or integrate with
 * your data source as needed.
 */

const PORT = Number(process.env.PORT ?? 8787)

const sampleEnvelope = {
  version: 1,
  id: 0,
  delegator: '0x0001000003014a3414606b1d3712da91bf4f49ffc61f88235f5ad9e147',
  agent: '0x0001000003014a3414a46e7833371c5c22396ddfe14628027e9b7ff065',
  payload: {
    association: 'Delegated Agent',
    name: 'Orbit AI',
    description: 'Example delegation resolved via offchain gateway',
    endpoints: [
      {
        name: 'A2A',
        endpoint: 'https://agent.example/.well-known/agent-card.json',
      },
    ],
  },
}

const server = http.createServer(async (req, res) => {
  if (req.method !== 'POST') {
    res.writeHead(405, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ error: 'Method not allowed' }))
    return
  }

  try {
    const chunks: Buffer[] = []
    for await (const chunk of req) {
      chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk)
    }

    const body = Buffer.concat(chunks).toString('utf8')
    console.log('Received offchain request:', body || '<empty>')

    // Encode the response as ABI-encoded string. Clients decode it in the
    // resolver callback.
    const payloadJson = JSON.stringify(sampleEnvelope)
    const abiEncodedString = encodeAbiString(payloadJson)

    res.writeHead(200, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ data: abiEncodedString }))
  } catch (error) {
    console.error('Gateway error:', error)
    res.writeHead(500, { 'content-type': 'application/json' })
    res.end(JSON.stringify({ error: 'Internal server error' }))
  }
})

server.listen(PORT, () => {
  console.log(`Agent delegations offchain resolver running on http://localhost:${PORT}`)
})

function encodeAbiString(value: string): `0x${string}` {
  const encoder = new TextEncoder()
  const utf8 = encoder.encode(value)

  // ABI string encoding = length (padded 32 bytes) + data (padded to /32)
  const lengthHex = utf8.length.toString(16).padStart(64, '0')
  const dataHex = Buffer.from(utf8).toString('hex').padEnd(Math.ceil(utf8.length / 32) * 64, '0')
  return `0x${lengthHex}${dataHex}`
}
