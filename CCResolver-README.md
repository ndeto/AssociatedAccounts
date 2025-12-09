# CCResolver - Controlled Accounts ENS Extended Resolver

CCResolver is an ENS Extended Resolver that provides verifiable on-chain proof of controlled accounts through cryptographic signatures using the ERC-8092 Associated Accounts standard.

## Overview

CCResolver allows you to:
1. Register a parent account with multiple controlled child accounts
2. Verify relationships through cryptographic signatures stored in AssociationsStore
3. Query controlled accounts via ENS text records with real-time signature verification
4. Support K1 (secp256k1 EOAs) and ERC-1271 (smart contract wallets on same chain)
5. Update the text record prefix without redeployment (owner-controlled)

## Architecture

```
    ┌─────────────────┐
    │   ENS Domain    │
    │  (example.eth)  │
    └────────┬────────┘
             │
             │ text("eth.ecs.controlled-accounts:<id>")
             ▼
┌─────────────────────────────────────────┐
│           CCResolver                    │
│  ┌────────────────────────────────┐     │
│  │  Registry: ID → ControlledAccts│     │
│  └────────────────────────────────┘     │
└────────────┬────────────────────────────┘
             │
             │ validates associations
             ▼
┌─────────────────────────────────────────┐
│       AssociationsStore                 │
│  ┌────────────────────────────────┐     │
│  │  SignedAssociationRecords      │     │
│  │  (with "ControlledAccount")    │     │
│  └────────────────────────────────┘     │
└─────────────────────────────────────────┘
```

## Key Concepts

### Controlled Accounts Structure

```solidity
struct ControlledAccounts {
    uint256 id;                  // Auto-assigned unique identifier (sequential)
    bytes parentAccount;         // Parent account (ERC-7930 format)
    bytes[] childAccounts;       // Array of controlled accounts (ERC-7930 format)
    uint256 registeredAt;        // Registration timestamp
}
```

### Association Requirements

For an account to be recognized as "controlled", an association must exist where:
- **Initiator**: Parent/delegate account
- **Approver**: Child/controlled account
- **Data field**: Must contain the string `"ControlledAccount"`
- **Signatures**: Both parties must sign the EIP-712 hash of the record
- **Validity**: Must be currently valid (not expired, not revoked)

## Usage

### 1. Creating Associations

First, create associations between parent and child accounts in the AssociationsStore:

```solidity
// Create association record
AssociatedAccountRecord memory record = AssociatedAccountRecord({
    initiator: parentAccount,      // ERC-7930 format
    approver: childAccount,        // ERC-7930 format
    validAt: uint40(block.timestamp),
    validUntil: 0,                 // 0 = no expiration
    interfaceId: bytes4(0),
    data: bytes("ControlledAccount") // Required!
});

// Generate EIP-712 hash
bytes32 hash = AssociatedAccountsLib.eip712Hash(record);

// Sign by parent
bytes memory parentSignature = signMessage(hash, parentPrivateKey);

// Sign by child
bytes memory childSignature = signMessage(hash, childPrivateKey);

// Create signed record
SignedAssociationRecord memory sar = SignedAssociationRecord({
    revokedAt: 0,
    initiatorKeyType: K1,          // secp256k1 ECDSA
    approverKeyType: K1,
    initiatorSignature: parentSignature,
    approverSignature: childSignature,
    record: record
});

// Store in AssociationsStore
associationsStore.storeAssociation(sar);
```

### 2. Registering Controlled Accounts

Once associations exist, register them with CCResolver. The ID is auto-assigned:

```solidity
bytes memory parent = InteroperableAddress.formatEvmV1(chainId, parentAddress);
bytes[] memory children = new bytes[](2);
children[0] = InteroperableAddress.formatEvmV1(chainId, child1Address);
children[1] = InteroperableAddress.formatEvmV1(chainId, child2Address);

// Returns auto-assigned ID (starting from 0)
uint256 id = ccResolver.registerControlledAccounts(parent, children);
```

### 3. Querying via ENS

Query controlled accounts through the ENS Extended Resolver interface:

```solidity
// Option 1: Via resolve() (standard ENS Extended Resolver)
bytes32 node = namehash("example.eth");
string memory key = string(abi.encodePacked("eth.ecs.controlled-accounts:", Strings.toString(id)));

// Encode the text(bytes32,string) call
bytes memory data = abi.encodeWithSelector(
    bytes4(0x59d1d43c), // text(bytes32,string) selector
    node,
    key
);

bytes memory name = dnsEncode("example.eth");
bytes memory result = ccResolver.resolve(name, data);

// Decode to get YAML string
string memory yamlOutput = abi.decode(result, (string));

// Option 2: Via text() directly (convenience function)
string memory yamlOutput = ccResolver.text(node, key);
```

**YAML Output Format:**

```yaml
id: 0
registeredAt: 1234567890
parent: "0x00010000027a69147e5f4552091a69125d5dfcb7b8c2659029395bdf"
children:
  - "0x00010000027a69142b5ad5c4795c026514f8317c7a215e218dccd6cf"
  - "0x00010000027a69146813eb9362372eef6200f3b1dbc3f819671cba69"
```

The addresses are in ERC-7930 Interoperable Address format (hex-encoded).

### 4. Direct Queries

You can also query directly without ENS:

```solidity
// Get controlled accounts struct (for on-chain use)
CCResolver.ControlledAccounts memory ca = ccResolver.getControlledAccounts(id);

// Get YAML output (for ENS/off-chain use)
string memory yaml = ccResolver.text(node, key);

// Check if valid (verifies all signatures in real-time)
bool valid = ccResolver.isValid(id);
```

### 5. Parsing YAML Output

Off-chain applications can easily parse the YAML output:

**JavaScript/TypeScript:**
```javascript
import yaml from 'js-yaml';

const yamlOutput = await resolver.text(node, `eth.ecs.controlled-accounts:${id}`);
const data = yaml.load(yamlOutput);

console.log('ID:', data.id);          // Number (e.g., 0, 1, 2)
console.log('Parent:', data.parent);
console.log('Children:', data.children);
```

**Python:**
```python
import yaml

yaml_output = resolver.functions.text(node, f"eth.ecs.controlled-accounts:{id}").call()
data = yaml.safe_load(yaml_output)

print(f"ID: {data['id']}")            # Integer
print(f"Parent: {data['parent']}")
print(f"Children: {data['children']}")
```

## Supported Signature Types

CCResolver supports the following key types through AssociationsStore:

| Key Type | ID | Support | Description |
|----------|------|---------|-------------|
| K1 | `0x0001` | ✅ Full | secp256k1 ECDSA (EOAs) |
| ERC-1271 | `0x8002` | ⚠️ Same-chain only | Smart contract signatures |
| R1 | `0x0002` | ❌ Not yet implemented | secp256r1 (Passkeys) - requires RIP-7212 |
| EDDSA | `0x0003` | ❌ Not yet implemented | EdDSA signatures |
| BLS | `0x0004` | ❌ Not yet implemented | BLS signatures |
| WEBAUTHN | `0x8001` | ❌ Not yet implemented | WebAuthn |
| ERC-6492 | `0x8003` | ❌ Not yet implemented | Counterfactual signatures |

### Cross-Chain Limitation

**Important**: ERC-1271 signatures only work when the smart contract wallet is on the same chain as the CCResolver deployment. Cross-chain ERC-1271 validation is not currently supported because it requires making contract calls.

## Owner Functions

CCResolver includes owner-controlled functions for managing the text record prefix:

```solidity
// Update the text record prefix (owner only)
function setTextRecordPrefix(string calldata newPrefix) external onlyOwner

// Transfer ownership (owner only)
function transferOwnership(address newOwner) external onlyOwner

// Public state variables
string public textRecordPrefix;  // Current prefix (default: "eth.ecs.controlled-accounts:")
address public owner;             // Contract owner
```

**Example:**
```solidity
// Change prefix to support different namespace
ccResolver.setTextRecordPrefix("new.namespace:");

// Transfer ownership
ccResolver.transferOwnership(newOwnerAddress);
```

## Security Considerations

1. **Read-Time Verification**: Verification happens at query time, not registration time
   - Always returns current state (no stale data)
   - Automatically handles revocations
   - Respects timestamp expiry
2. **Expiration**: Associations can have `validUntil` timestamps
3. **Revocation**: Either party can revoke an association - immediately reflected in queries
4. **Data Integrity**: The `"ControlledAccount"` data field must be present
5. **Role Verification**: Parent must be initiator, child must be approver
6. **Graceful Failure**: Invalid associations return empty string instead of reverting
7. **Owner Control**: Only the owner can update the text record prefix or transfer ownership
8. **Sequential IDs**: IDs are auto-assigned sequentially (0, 1, 2, ...) to prevent squatting

## Deployment

### Deploy with Existing AssociationsStore

```bash
forge script script/DeployCCResolver.s.sol:DeployCCResolverScript \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    -vvvv
```

Set environment variables:
```bash
export DEPLOYER_PRIVATE_KEY=0x...
export ASSOCIATIONS_STORE_ADDRESS=0x...  # Optional
```

### Deploy New Stack

If `ASSOCIATIONS_STORE_ADDRESS` is not set, a new AssociationsStore will be deployed automatically.

## Events

### ControlledAccountsRegistered
```solidity
event ControlledAccountsRegistered(
    uint256 indexed id,
    bytes parentAccount,
    bytes[] childAccounts,
    address registrar
);
```

**Note:** Controlled accounts are immutable once registered. To change the list, register a new ID.

## Error Reference

| Error | Description |
|-------|-------------|
| `IdNotFound()` | ID doesn't exist |
| `NoChildAccounts()` | Empty children array |
| `InvalidAssociation(bytes32)` | Association validation failed |
| `InvalidData(bytes32, bytes)` | Data field doesn't contain "ControlledAccount" |
| `WrongAccountRoles(bytes32)` | Parent/child roles don't match initiator/approver |
| `OnlyOwner()` | Caller is not the owner |

## Testing

Run the test suite:

```bash
forge test --match-contract CCResolverTest -vv
```

## Integration with ENS

To use CCResolver as your ENS Extended Resolver:

1. Deploy CCResolver
2. Set it as resolver for your ENS name:
   ```solidity
   ensRegistry.setResolver(node, address(ccResolver));
   ```
3. Register your controlled accounts with an ID
4. Query via ENS Extended Resolver interface:
   - Use `resolve(bytes name, bytes data)` for standard ENS calls
   - Use `text(bytes32 node, string key)` for direct queries

### ENS Extended Resolver Interface

CCResolver implements the ENS Extended Resolver interface (`IExtendedResolver`):

```solidity
interface IExtendedResolver {
    function resolve(bytes calldata name, bytes calldata data) 
        external view returns (bytes memory);
}
```

### Text Record Key Format

By default, text records use the prefix `eth.ecs.controlled-accounts:` followed by the numeric ID:

- `eth.ecs.controlled-accounts:0`
- `eth.ecs.controlled-accounts:1`
- `eth.ecs.controlled-accounts:2`

The owner can update this prefix using `setTextRecordPrefix()` to support different namespaces without redeployment.

## License

MIT

## References

- [ERC-8092: Associated Accounts](https://github.com/ethereum/ERCs/pull/1377)
- [ERC-7930: Interoperable Address Format](https://eips.ethereum.org/EIPS/eip-7930)
- [EIP-712: Typed Data Signing](https://eips.ethereum.org/EIPS/eip-712)
- [ERC-1271: Smart Contract Signatures](https://eips.ethereum.org/EIPS/eip-1271)

