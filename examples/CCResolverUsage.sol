// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {CCResolver} from "../src/CCResolver.sol";
import {AssociationsStore} from "../src/AssociationsStore.sol";
import {AssociatedAccounts} from "../src/AssociatedAccounts.sol";
import {AssociatedAccountsLib} from "../src/AssociatedAccountsLib.sol";
import {InteroperableAddress} from "../src/InteroperableAddresses.sol";
import "../src/KeyTypes.sol";

/// @title CCResolverUsage
/// @notice Example contract demonstrating how to use CCResolver
/// @dev This is for educational purposes - not for production use
contract CCResolverUsageExample {
    CCResolver public resolver;
    AssociationsStore public store;

    constructor(address _store, address _resolver) {
        store = AssociationsStore(_store);
        resolver = CCResolver(_resolver);
    }

    /// @notice Example: Create and register a controlled accounts structure
    /// @param parentAddr The parent wallet address
    /// @param childAddrs Array of child wallet addresses
    /// @param parentSig Parent's signature of each association
    /// @param childSigs Children's signatures of their associations
    /// @return id The registered controlled accounts ID
    function createControlledAccountsStructure(
        address parentAddr,
        address[] calldata childAddrs,
        bytes[] calldata parentSigs,
        bytes[] calldata childSigs
    ) external returns (bytes32 id) {
        require(childAddrs.length > 0, "Need at least one child");
        require(parentSigs.length == childAddrs.length, "Signature count mismatch");
        require(childSigs.length == childAddrs.length, "Signature count mismatch");

        // Convert to ERC-7930 format
        bytes memory parentAccount = InteroperableAddress.formatEvmV1(block.chainid, parentAddr);
        bytes[] memory childAccounts = new bytes[](childAddrs.length);
        
        for (uint256 i = 0; i < childAddrs.length; i++) {
            childAccounts[i] = InteroperableAddress.formatEvmV1(block.chainid, childAddrs[i]);
        }

        // Create associations for each child
        for (uint256 i = 0; i < childAddrs.length; i++) {
            _createAssociation(
                parentAccount,
                childAccounts[i],
                parentSigs[i],
                childSigs[i]
            );
        }

        // Generate unique ID
        id = keccak256(abi.encodePacked(
            parentAddr,
            childAddrs,
            block.timestamp,
            block.number
        ));

        // Register with CCResolver
        resolver.registerControlledAccounts(id, parentAccount, childAccounts);

        return id;
    }

    /// @notice Example: Query controlled accounts by ID
    /// @param id The controlled accounts ID
    /// @return parentAddr The parent address
    /// @return childAddrs Array of child addresses
    function queryControlledAccounts(bytes32 id)
        external
        view
        returns (address parentAddr, address[] memory childAddrs)
    {
        // Get from resolver
        CCResolver.ControlledAccounts memory ca = resolver.getControlledAccounts(id);

        // Parse parent
        (, , bytes memory parentBytes) = InteroperableAddress.parseV1(ca.parentAccount);
        parentAddr = address(bytes20(parentBytes));

        // Parse children
        childAddrs = new address[](ca.childAccounts.length);
        for (uint256 i = 0; i < ca.childAccounts.length; i++) {
            (, , bytes memory childBytes) = InteroperableAddress.parseV1(ca.childAccounts[i]);
            childAddrs[i] = address(bytes20(childBytes));
        }

        return (parentAddr, childAddrs);
    }

    /// @notice Example: Verify controlled accounts are currently valid
    /// @param id The controlled accounts ID
    /// @return valid True if all signatures are valid
    function verifyControlledAccounts(bytes32 id) external view returns (bool valid) {
        return resolver.isValid(id);
    }

    /// @notice Example: Query via ENS text record format
    /// @param id The controlled accounts ID
    /// @return The ABI-encoded result
    function queryViaTextRecord(bytes32 id) external view returns (string memory) {
        bytes32 node = keccak256("example.eth");
        string memory key = string(abi.encodePacked("controlled-accounts:", id));
        return resolver.text(node, key);
    }

    /// @notice Example: Update controlled accounts (add/remove children)
    /// @param id Existing controlled accounts ID
    /// @param parentAddr The parent wallet address
    /// @param newChildAddrs New array of child wallet addresses
    /// @param parentSigs Parent's signatures for new associations
    /// @param childSigs Children's signatures for new associations
    function updateControlledAccounts(
        bytes32 id,
        address parentAddr,
        address[] calldata newChildAddrs,
        bytes[] calldata parentSigs,
        bytes[] calldata childSigs
    ) external {
        require(newChildAddrs.length > 0, "Need at least one child");
        require(parentSigs.length == newChildAddrs.length, "Signature count mismatch");
        require(childSigs.length == newChildAddrs.length, "Signature count mismatch");

        // Convert to ERC-7930 format
        bytes memory parentAccount = InteroperableAddress.formatEvmV1(block.chainid, parentAddr);
        bytes[] memory childAccounts = new bytes[](newChildAddrs.length);
        
        for (uint256 i = 0; i < newChildAddrs.length; i++) {
            childAccounts[i] = InteroperableAddress.formatEvmV1(block.chainid, newChildAddrs[i]);
        }

        // Create new associations
        for (uint256 i = 0; i < newChildAddrs.length; i++) {
            // Check if association already exists
            (bool exists, ) = store.getAssociationBetweenAccounts(parentAccount, childAccounts[i]);
            
            if (!exists) {
                _createAssociation(
                    parentAccount,
                    childAccounts[i],
                    parentSigs[i],
                    childSigs[i]
                );
            }
        }

        // Update in resolver
        resolver.updateControlledAccounts(id, parentAccount, childAccounts);
    }

    /// @notice Internal helper to create an association
    function _createAssociation(
        bytes memory parentAccount,
        bytes memory childAccount,
        bytes memory parentSig,
        bytes memory childSig
    ) internal {
        // Create association record
        AssociatedAccounts.AssociatedAccountRecord memory record = 
            AssociatedAccounts.AssociatedAccountRecord({
                initiator: parentAccount,
                approver: childAccount,
                validAt: uint40(block.timestamp),
                validUntil: 0, // No expiration
                interfaceId: bytes4(0),
                data: bytes("ControlledAccount")
            });

        // Create signed record
        AssociatedAccounts.SignedAssociationRecord memory sar = 
            AssociatedAccounts.SignedAssociationRecord({
                revokedAt: 0,
                initiatorKeyType: K1, // secp256k1 ECDSA
                approverKeyType: K1,
                initiatorSignature: parentSig,
                approverSignature: childSig,
                record: record
            });

        // Store in AssociationsStore
        store.storeAssociation(sar);
    }

    /// @notice Example: Check if a specific child is controlled by a parent
    /// @param id The controlled accounts ID
    /// @param childAddr The child address to check
    /// @return True if the child is in the controlled accounts list
    function isChildControlled(bytes32 id, address childAddr) 
        external 
        view 
        returns (bool) 
    {
        CCResolver.ControlledAccounts memory ca = resolver.getControlledAccounts(id);
        bytes memory childAccount = InteroperableAddress.formatEvmV1(block.chainid, childAddr);
        bytes32 childHash = keccak256(childAccount);

        for (uint256 i = 0; i < ca.childAccounts.length; i++) {
            if (keccak256(ca.childAccounts[i]) == childHash) {
                return true;
            }
        }
        return false;
    }

    /// @notice Example: Get all controlled accounts IDs for display
    /// @dev This is a placeholder - in production you'd maintain an index
    /// @return Array of all registered IDs (limited example)
    function getAllControlledAccountIds() external pure returns (bytes32[] memory) {
        // In production, you'd maintain a registry of IDs
        // This is just a placeholder for the example
        bytes32[] memory ids = new bytes32[](0);
        return ids;
    }
}

/// @title Off-chain Helper
/// @notice Example functions for off-chain signature generation
/// @dev These would typically be done off-chain in your application
library OffChainHelper {
    /// @notice Generate the EIP-712 hash for an association
    /// @param parentAccount Parent account in ERC-7930 format
    /// @param childAccount Child account in ERC-7930 format
    /// @return The hash to be signed
    function generateHashToSign(
        bytes memory parentAccount,
        bytes memory childAccount
    ) internal view returns (bytes32) {
        AssociatedAccounts.AssociatedAccountRecord memory record = 
            AssociatedAccounts.AssociatedAccountRecord({
                initiator: parentAccount,
                approver: childAccount,
                validAt: uint40(block.timestamp),
                validUntil: 0,
                interfaceId: bytes4(0),
                data: bytes("ControlledAccount")
            });

        return AssociatedAccountsLib.eip712Hash(record);
    }

    /// @notice Example of how to format addresses for use
    /// @param chainId The EVM chain ID
    /// @param addr The Ethereum address
    /// @return The ERC-7930 formatted address
    function formatAddress(uint256 chainId, address addr) internal pure returns (bytes memory) {
        return InteroperableAddress.formatEvmV1(chainId, addr);
    }

    /// @notice Example of how to parse addresses back
    /// @param account The ERC-7930 formatted address
    /// @return chainType The chain type (should be 0x8001 for EIP-155)
    /// @return chainId The chain ID
    /// @return addr The Ethereum address
    function parseAddress(bytes memory account) 
        internal 
        pure 
        returns (bytes2 chainType, uint256 chainId, address addr) 
    {
        (chainType, bytes memory chainRef, bytes memory addrBytes) = 
            InteroperableAddress.parseV1(account);
        
        chainId = uint256(bytes32(chainRef));
        addr = address(bytes20(addrBytes));
    }
}

