// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {AssociationsStore} from "../src/AssociationsStore.sol";
import {AssociatedAccounts} from "../src/AssociatedAccounts.sol";
import {AssociatedAccountsLib} from "../src/AssociatedAccountsLib.sol";
import {InteroperableAddress} from "../src/InteroperableAddresses.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SignatureChecker} from "lib/openzeppelin-contracts/contracts/utils/cryptography/SignatureChecker.sol";
import "../src/KeyTypes.sol";

/// @notice Tests for K1 signature validation
contract SignatureValidationTest is Test {
    using AssociatedAccountsLib for *;

    AssociationsStore public store;

    // Test accounts
    uint256 parentPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
    uint256 childPrivateKey = 0x2234567890123456789012345678901234567890123456789012345678901234;
    
    address parentAddress;
    address childAddress;

    bytes parentAccount;
    bytes childAccount;

    function setUp() public {
        store = new AssociationsStore();
        
        parentAddress = vm.addr(parentPrivateKey);
        childAddress = vm.addr(childPrivateKey);

        uint256 chainId = block.chainid;
        parentAccount = InteroperableAddress.formatEvmV1(chainId, parentAddress);
        childAccount = InteroperableAddress.formatEvmV1(chainId, childAddress);

        console2.log("Parent Address:", parentAddress);
        console2.log("Child Address:", childAddress);
    }

    /// @notice Test basic ECDSA signature recovery
    function test_BasicECDSARecovery() public view {
        bytes32 testHash = keccak256("test message");
        
        // Sign with parent key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(parentPrivateKey, testHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console2.log("Signature length:", signature.length);
        console2.log("V:", v);
        
        // Try ECDSA recovery
        (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(testHash, signature);
        
        console2.log("Recovered address:", recovered);
        console2.log("Expected address:", parentAddress);
        console2.log("Error code:", uint256(error));
        
        assertEq(uint256(error), uint256(ECDSA.RecoverError.NoError), "ECDSA recovery failed");
        assertEq(recovered, parentAddress, "Recovered address doesn't match");
    }

    /// @notice Test SignatureChecker on EOA
    function test_SignatureCheckerOnEOA() public view {
        bytes32 testHash = keccak256("test message");
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(parentPrivateKey, testHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        console2.log("\n=== Testing SignatureChecker.isValidSignatureNow ===");
        
        bool isValid = SignatureChecker.isValidSignatureNow(parentAddress, testHash, signature);
        
        console2.log("SignatureChecker result:", isValid);
        assertTrue(isValid, "SignatureChecker should validate EOA signature");
    }

    /// @notice Test EIP-712 hash generation
    function test_EIP712HashGeneration() public view {
        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts
            .AssociatedAccountRecord({
            initiator: parentAccount,
            approver: childAccount,
            validAt: uint40(block.timestamp),
            validUntil: 0,
            interfaceId: bytes4(0),
            data: bytes("ControlledAccount")
        });

        bytes32 hash = AssociatedAccountsLib.eip712Hash(record);
        console2.log("EIP-712 hash:");
        console2.logBytes32(hash);

        // Verify it's deterministic
        bytes32 hash2 = AssociatedAccountsLib.eip712Hash(record);
        assertEq(hash, hash2, "EIP-712 hash should be deterministic");
    }

    /// @notice Test ECDSA recovery on signatures
    function test_ECDSARecoveryOnEIP712Signatures() public view {
        AssociatedAccounts.SignedAssociationRecord memory sar = _createSignedRecord();
        bytes32 hash = AssociatedAccountsLib.eip712Hash(sar.record);

        console2.log("\n=== Testing ECDSA Recovery on EIP-712 Signatures ===");
        
        (address recoveredParent,,) = ECDSA.tryRecover(hash, sar.initiatorSignature);
        console2.log("Parent recovered:", recoveredParent);
        assertEq(recoveredParent, parentAddress, "Parent ECDSA recovery failed");

        (address recoveredChild,,) = ECDSA.tryRecover(hash, sar.approverSignature);
        console2.log("Child recovered:", recoveredChild);
        assertEq(recoveredChild, childAddress, "Child ECDSA recovery failed");
    }

    /// @notice Test SignatureChecker on EIP-712 signatures
    function test_SignatureCheckerOnEIP712() public view {
        AssociatedAccounts.SignedAssociationRecord memory sar = _createSignedRecord();
        bytes32 hash = AssociatedAccountsLib.eip712Hash(sar.record);

        console2.log("\n=== Testing SignatureChecker on EIP-712 ===");
        
        assertTrue(
            SignatureChecker.isValidSignatureNow(parentAddress, hash, sar.initiatorSignature),
            "Parent SignatureChecker failed"
        );
        console2.log("Parent: PASSED");

        assertTrue(
            SignatureChecker.isValidSignatureNow(childAddress, hash, sar.approverSignature),
            "Child SignatureChecker failed"
        );
        console2.log("Child: PASSED");
    }

    /// @notice Test full association record validation
    function test_FullAssociationValidation() public view {
        console2.log("\n=== Testing Full Association Record Validation ===");
        
        AssociatedAccounts.SignedAssociationRecord memory sar = _createSignedRecord();
        assertTrue(sar.validateAssociatedAccount(), "Full validation failed");
        console2.log("Full validation: PASSED");
    }

    /// @notice Helper to create a signed association record
    function _createSignedRecord() internal view returns (AssociatedAccounts.SignedAssociationRecord memory) {
        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts
            .AssociatedAccountRecord({
            initiator: parentAccount,
            approver: childAccount,
            validAt: uint40(block.timestamp),
            validUntil: 0,
            interfaceId: bytes4(0),
            data: bytes("ControlledAccount")
        });

        bytes32 hash = AssociatedAccountsLib.eip712Hash(record);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(parentPrivateKey, hash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(childPrivateKey, hash);

        return AssociatedAccounts.SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1,
            approverKeyType: K1,
            initiatorSignature: abi.encodePacked(r1, s1, v1),
            approverSignature: abi.encodePacked(r2, s2, v2),
            record: record
        });
    }

    /// @notice Test storing association in AssociationsStore
    function test_StoreAssociation() public {
        console2.log("\n=== Storing in AssociationsStore ===");
        
        AssociatedAccounts.SignedAssociationRecord memory sar = _createSignedRecord();
        
        // This should work without reverting
        store.storeAssociation(sar);

        bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
        console2.log("Association stored successfully!");
        console2.logBytes32(associationId);

        // Verify it was stored
        AssociatedAccounts.SignedAssociationRecord memory retrieved = store.getAssociation(associationId);
        assertEq(retrieved.record.validAt, sar.record.validAt, "Retrieved record doesn't match");
    }

    /// @notice Test validation with wrong signer
    function test_RevertIfWrongSigner() public {
        AssociatedAccounts.SignedAssociationRecord memory sar = _createSignedRecord();
        
        // Replace parent signature with wrong one
        uint256 wrongKey = 0x9999999999999999999999999999999999999999999999999999999999999999;
        bytes32 hash = AssociatedAccountsLib.eip712Hash(sar.record);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, hash);
        sar.initiatorSignature = abi.encodePacked(r, s, v);

        // Should fail validation
        assertFalse(sar.validateAssociatedAccount(), "Should reject wrong signer");

        // Should revert when trying to store
        vm.expectRevert(AssociationsStore.InvalidAssociation.selector);
        store.storeAssociation(sar);
    }
}

