// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {AssociationsStore} from "../src/AssociationsStore.sol";
import {CCResolver} from "../src/CCResolver.sol";
import {AssociatedAccounts} from "../src/AssociatedAccounts.sol";
import {AssociatedAccountsLib} from "../src/AssociatedAccountsLib.sol";
import {InteroperableAddress} from "../src/InteroperableAddresses.sol";
import "../src/KeyTypes.sol";

/// @notice Example script to register controlled accounts
/// @dev Creates parent account with 2 child accounts and registers in CCResolver
contract RegisterControlledAccountsExampleScript is Script {
    using AssociatedAccountsLib for *;

    // Contract addresses (will be loaded from environment)
    AssociationsStore public associationsStore;
    CCResolver public ccResolver;

    // Test accounts
    address public parentAddress;
    address public child1Address;
    address public child2Address;

    // Private keys for signing
    uint256 public parentPrivateKey;
    uint256 public child1PrivateKey;
    uint256 public child2PrivateKey;

    function setUp() public {
        // Load contract addresses from environment
        address storeAddress = vm.envAddress("ASSOCIATIONS_STORE_ADDRESS");
        address resolverAddress = vm.envAddress("CC_RESOLVER_ADDRESS");

        associationsStore = AssociationsStore(storeAddress);
        ccResolver = CCResolver(resolverAddress);

        // Load test account private keys from environment
        parentPrivateKey = vm.envUint("PARENT_PRIVATE_KEY");
        child1PrivateKey = vm.envUint("CHILD1_PRIVATE_KEY");
        child2PrivateKey = vm.envUint("CHILD2_PRIVATE_KEY");

        parentAddress = vm.addr(parentPrivateKey);
        child1Address = vm.addr(child1PrivateKey);
        child2Address = vm.addr(child2PrivateKey);

        console2.log("\n=== Test Accounts ===");
        console2.log("Parent Address:", parentAddress);
        console2.log("Child 1 Address:", child1Address);
        console2.log("Child 2 Address:", child2Address);
    }

    function run() public {
        // Get deployer to pay for transactions
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 chainId = block.chainid;

        vm.startBroadcast(deployerPrivateKey);

        console2.log("\n=== Step 1: Creating Associations ===");

        // Create ERC-7930 formatted addresses
        bytes memory parentAccount = InteroperableAddress.formatEvmV1(chainId, parentAddress);
        bytes memory child1Account = InteroperableAddress.formatEvmV1(chainId, child1Address);
        bytes memory child2Account = InteroperableAddress.formatEvmV1(chainId, child2Address);

        // Create and store association: parent -> child1
        console2.log("\nCreating association: parent -> child1");
        _createAndStoreAssociation(
            parentAccount,
            child1Account,
            parentPrivateKey,
            child1PrivateKey
        );

        // Create and store association: parent -> child2
        console2.log("Creating association: parent -> child2");
        _createAndStoreAssociation(
            parentAccount,
            child2Account,
            parentPrivateKey,
            child2PrivateKey
        );

        console2.log("\n=== Step 2: Registering Controlled Accounts ===");

        // Register controlled accounts in CCResolver
        bytes[] memory children = new bytes[](2);
        children[0] = child1Account;
        children[1] = child2Account;

        uint256 controlledAccountsId = ccResolver.registerControlledAccounts(
            parentAccount,
            children
        );

        console2.log("Controlled Accounts Registered!");
        console2.log("ID:", controlledAccountsId);

        vm.stopBroadcast();

        console2.log("\n=== Step 3: Verifying Registration ===");

        // Verify the registration
        bool isValid = ccResolver.isValid(controlledAccountsId);
        console2.log("Is Valid:", isValid);

        if (isValid) {
            // Get the current prefix from the resolver
            string memory prefix = ccResolver.textRecordPrefix();
            
            // Query the controlled accounts
            string memory key = string(abi.encodePacked(prefix, vm.toString(controlledAccountsId)));
            bytes32 node = keccak256("example.eth");
            string memory yamlOutput = ccResolver.text(node, key);

            console2.log("\n=== YAML Output ===");
            console2.log(yamlOutput);
        } else {
            console2.log("WARNING: Registration is not valid!");
        }

        console2.log("\n=== Summary ===");
        console2.log("AssociationsStore:", address(associationsStore));
        console2.log("CCResolver:", address(ccResolver));
        console2.log("Text Record Prefix:", ccResolver.textRecordPrefix());
        console2.log("Controlled Accounts ID:", controlledAccountsId);
        console2.log("Parent:", parentAddress);
        console2.log("Child 1:", child1Address);
        console2.log("Child 2:", child2Address);
        console2.log("\nQuery via ENS:");
        console2.log("  Key:", string(abi.encodePacked(ccResolver.textRecordPrefix(), vm.toString(controlledAccountsId))));
    }

    /// @notice Creates and stores an association between two accounts
    function _createAndStoreAssociation(
        bytes memory initiator,
        bytes memory approver,
        uint256 initiatorPrivateKey,
        uint256 approverPrivateKey
    ) internal {
        // Create association record
        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts
            .AssociatedAccountRecord({
            initiator: initiator,
            approver: approver,
            validAt: uint40(block.timestamp),
            validUntil: 0, // No expiration
            interfaceId: bytes4(0),
            data: bytes("ControlledAccount") // Required for CCResolver
        });

        // Generate EIP-712 hash
        bytes32 hash = AssociatedAccountsLib.eip712Hash(record);

        // Sign with initiator (parent)
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(initiatorPrivateKey, hash);
        bytes memory initiatorSignature = abi.encodePacked(r1, s1, v1);

        // Sign with approver (child)
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(approverPrivateKey, hash);
        bytes memory approverSignature = abi.encodePacked(r2, s2, v2);

        // Create signed association record
        AssociatedAccounts.SignedAssociationRecord memory sar = AssociatedAccounts
            .SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1, // secp256k1 ECDSA
            approverKeyType: K1,
            initiatorSignature: initiatorSignature,
            approverSignature: approverSignature,
            record: record
        });

        // Store in AssociationsStore
        associationsStore.storeAssociation(sar);

        bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
        console2.log("  Association ID:", vm.toString(associationId));
    }
}

