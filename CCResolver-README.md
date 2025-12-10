# CCResolver v0.1.0 - Full ENS Resolver with Controlled Accounts

CCResolver is a complete ENS Extended Resolver that provides verifiable on-chain proof of controlled accounts through cryptographic signatures using the ERC-8092 Associated Accounts standard, plus full support for standard ENS records.

## Overview

CCResolver allows you to:
1. **Controlled Accounts**: Register parent accounts with multiple controlled child accounts
2. **Cryptographic Verification**: Verify relationships through EIP-712 signatures stored in AssociationsStore
3. **Real-Time Validation**: Query controlled accounts with real-time signature verification
4. **Full ENS Support**: Set and query text, data, addr, and contenthash records
5. **Multi-Coin Addresses**: Support for multiple cryptocurrency address types (ENSIP-11)
6. **ERC-165 Compatible**: Proper interface detection support
7. **Updatable Prefix**: Owner can update controlled-accounts prefix without redeployment

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

## ENS Resolver Functions (v0.1.0)

### Setting Records (Owner Only)

CCResolver v0.1.0 includes full ENS resolver functionality:

```solidity
// Text Records (ENSIP-5)
function setText(string calldata _key, string calldata _value) external onlyOwner

// Data Records (binary data storage)
function setData(string calldata _key, bytes calldata _data) external onlyOwner

// Address Records (ENSIP-11 multi-coin)
function setAddr(address _addr) external onlyOwner  // ETH address
function setAddr(uint256 _coinType, bytes calldata _value) external onlyOwner

// Contenthash (IPFS/Arweave)
function setContenthash(bytes calldata _hash) external onlyOwner

// Prefix & Ownership Management
function setTextRecordPrefix(string calldata newPrefix) external onlyOwner
function transferOwnership(address newOwner) external onlyOwner
```

### Querying Records (Public)

```solidity
// Get text record
function text(bytes32 node, string calldata _key) external view returns (string memory)

// Get data record
function data(bytes32 node, string calldata _key) external view returns (bytes memory)

// Get address (coin type 60 = Ethereum)
function addr(bytes32 node, uint256 _coinType) external view returns (bytes memory)

// Get contenthash
function contenthash(bytes32 node) external view returns (bytes memory)

// Check interface support
function supportsInterface(bytes4 interfaceId) external pure returns (bool)
```

**Example Usage:**
```javascript
// Set resolver-info
await resolver.setText("resolver-info", "# CCResolver v0.1.0...");

// Set avatar
await resolver.setText("avatar", "https://example.com/avatar.png");

// Set social profiles
await resolver.setText("com.twitter", "@alice");
await resolver.setText("com.github", "alice");

// Set ETH address
await resolver.setAddr("0x1234567890123456789012345678901234567890");

// Set IPFS contenthash
const ipfsHash = "0xe301017012204edd2984eeaf3ddf50bac238ec95c5713fb40b5e428b508fdbe55d3b9f155ffe";
await resolver.setContenthash(ipfsHash);

// Query records
const node = ethers.namehash("yourname.eth");
const resolverInfo = await resolver.text(node, "resolver-info");
const avatar = await resolver.text(node, "avatar");
const ethAddr = await resolver.addr(node, 60);
const contentHash = await resolver.contenthash(node);
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

### Live Deployments

#### Ethereum Sepolia (Testnet) - v0.1.0 ⭐ LATEST

**ENS Name**: [`controlled-accounts.ecs.eth`](https://app.ens.domains/controlled-accounts.ecs.eth)

The CCResolver is now live as the resolver for `controlled-accounts.ecs.eth` on Sepolia:

- **ECS Name**: `controlled-accounts.ecs.eth`
- **Owner**: [`0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF`](https://sepolia.etherscan.io/address/0xF8e03bd4436371E0e2F7C02E529b2172fe72b4EF)
- **CCResolver v0.1.0**: [`0xAE5A879A021982B65A691dFdcE83528e8e13dFd3`](https://sepolia.etherscan.io/address/0xae5a879a021982b65a691dfdce83528e8e13dfd3)
- **AssociationsStore**: [`0x658CC576192a9e950DCd1BFb0F77F1D75a055D49`](https://sepolia.etherscan.io/address/0x658cc576192a9e950dcd1bfb0f77f1d75a055d49)
- **Text Record Prefix**: `eth.ecs.controlled-accounts:`
- **Version**: 0.1.0
- **Deployed**: December 9, 2025
- **Status**: ✅ Live with full ENS resolver support

**Features:**
- ✅ Controlled accounts verification
- ✅ Text records (ENSIP-5)
- ✅ Data records
- ✅ Multi-coin addresses (ENSIP-11)
- ✅ Contenthash support
- ✅ ERC-165 interface detection
- ✅ resolver-info metadata set

**Query resolver-info:**
```bash
cast call 0xAE5A879A021982B65A691dFdcE83528e8e13dFd3 \
  "text(bytes32,string)(string)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  "resolver-info" \
  --rpc-url $SEPOLIA_RPC_URL
```

**Query via ENS Name:**

You can now query controlled accounts using the registered ENS name:

```javascript
// Using ethers.js with ENS support
const provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
const resolver = await provider.getResolver("controlled-accounts.ecs.eth");
const controlledAccounts = await resolver.getText("eth.ecs.controlled-accounts:0");

// Returns YAML:
// id: 0
// registeredAt: 1765302228
// parent: "0x0001000003aa36a7144d45cd7472f2c46e81734c561a2d0b4b66c8fefe"
// children:
//   - "0x0001000003aa36a7144d45cd7472f2c46e81734c561a2d0b4b66c8fefe"
//   - "0x0001000003aa36a714cc8d7b159eafa8a2c4ca5c88c3f6b760761dbf28"
```

```bash
# Using cast (requires ENS resolution)
cast call 0xAE5A879A021982B65A691dFdcE83528e8e13dFd3 \
  "text(bytes32,string)(string)" \
  $(cast namehash controlled-accounts.ecs.eth) \
  "eth.ecs.controlled-accounts:0" \
  --rpc-url $SEPOLIA_RPC_URL
```

#### Base Sepolia (Testnet) - Previous Deployment
- **CCResolver**: [`0x91710e42A6f587d8728ccF1cB09Ded39FF4e456d`](https://sepolia.basescan.org/address/0x91710e42a6f587d8728ccf1cb09ded39ff4e456d)
- **AssociationsStore**: [`0x7Ed0BA8478CAAEA6A2Bc7368044b12D831129486`](https://sepolia.basescan.org/address/0x7ed0ba8478caaea6a2bc7368044b12d831129486)
- **Note**: Controlled accounts only (no full ENS resolver)

### Deploy Your Own

#### With Existing AssociationsStore

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

#### Deploy New Stack

If `ASSOCIATIONS_STORE_ADDRESS` is not set, a new AssociationsStore will be deployed automatically.

### Updating ENS Resolver (for controlled-accounts.ecs.eth)

The ENS name `controlled-accounts.ecs.eth` uses a commit-reveal pattern for security when updating resolvers:

#### Step 1: Commit Update
```bash
export NEW_CC_RESOLVER_ADDRESS=0x...  # New resolver address
export DEPLOYER_PRIVATE_KEY=0x...      # Owner private key

forge script script/CommitResolverUpdate.s.sol:CommitResolverUpdate \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vv

# Save the UPDATE_SECRET from script output
```

#### Step 2: Apply Update (after 60 seconds)
```bash
export UPDATE_SECRET=0x...  # From step 1 output

forge script script/UpdateResolverAddress.s.sol:UpdateResolverAddress \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  -vv
```

This two-step process prevents frontrunning attacks when updating critical ENS records.

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

### Run Test Suite

```bash
forge test --match-contract CCResolverTest -vv
```

All tests use numbered naming convention for better organization:
- `test_001____registerControlledAccounts__CanRegisterTwoChildren()`
- `test_002____text________________________ReturnsYAMLForValidId()`
- `test_008____setTextRecordPrefix_________UpdatesPrefixSuccessfully()`
- etc.

### Run Example Script

Create and register controlled accounts on a live network:

```bash
# Set up environment variables
export ASSOCIATIONS_STORE_ADDRESS=0x658CC576192a9e950DCd1BFb0F77F1D75a055D49  # Sepolia v0.1.0
export CC_RESOLVER_ADDRESS=0xAE5A879A021982B65A691dFdcE83528e8e13dFd3      # Sepolia v0.1.0
export PARENT_PRIVATE_KEY=0x...
export CHILD1_PRIVATE_KEY=0x...
export CHILD2_PRIVATE_KEY=0x...
export DEPLOYER_PRIVATE_KEY=0x...

# Run the example script
forge script script/RegisterControlledAccountsExample.s.sol:RegisterControlledAccountsExampleScript \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    -vv
```

The script will:
1. Create associations between parent and child accounts
2. Register controlled accounts in CCResolver
3. Verify the registration and display YAML output

### Set Resolver Info

Set the resolver-info metadata using the included script:

```bash
./script/SetResolverInfo.sh
```

This sets a concise resolver-info text record following the [resolver-info ENSIP standard](https://github.com/nxt3d/ensips/blob/resolver-info-metadata/ensips/resolver-info-text-record.md).

## Integration with ENS

### Live Example: controlled-accounts.ecs.eth

CCResolver v0.1.0 is currently deployed as the resolver for **`controlled-accounts.ecs.eth`** on Sepolia. This provides a working example of the integration.

**Query live controlled accounts:**
```javascript
const resolver = await provider.getResolver("controlled-accounts.ecs.eth");
const accounts = await resolver.getText("eth.ecs.controlled-accounts:0");
```

### Using CCResolver for Your ENS Name

To use CCResolver as your ENS Extended Resolver:

1. Deploy CCResolver (or use existing deployment)
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

## Version History

- **v0.1.0** (December 9, 2025)
  - Full ENS resolver support (text, data, addr, contenthash)
  - ERC-165 interface detection
  - Comprehensive event logging
  - resolver-info metadata set
  - Deployed: `0xAE5A879A021982B65A691dFdcE83528e8e13dFd3` (Sepolia)

## References

- [ERC-8092: Associated Accounts](https://github.com/ethereum/ERCs/pull/1377)
- [ERC-7930: Interoperable Address Format](https://eips.ethereum.org/EIPS/eip-7930)
- [EIP-712: Typed Data Signing](https://eips.ethereum.org/EIPS/eip-712)
- [ERC-1271: Smart Contract Signatures](https://eips.ethereum.org/EIPS/eip-1271)
- [ERC-165: Interface Detection](https://eips.ethereum.org/EIPS/eip-165)
- [ENSIP-5: Text Records](https://docs.ens.domains/ensip/5)
- [ENSIP-10: Extended Resolver](https://docs.ens.domains/ensip/10)
- [ENSIP-11: Multi-coin Address Resolution](https://docs.ens.domains/ensip/11)
- [Resolver-Info Standard](https://github.com/nxt3d/ensips/blob/resolver-info-metadata/ensips/resolver-info-text-record.md)

