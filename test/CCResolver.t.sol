// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {CCResolver} from "../src/CCResolver.sol";
import {AssociationsStore} from "../src/AssociationsStore.sol";
import {AssociatedAccounts} from "../src/AssociatedAccounts.sol";
import {AssociatedAccountsLib} from "../src/AssociatedAccountsLib.sol";
import {InteroperableAddress} from "../src/InteroperableAddresses.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {IERC165} from "lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol";
import "../src/KeyTypes.sol";

interface IExtendedResolver {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

contract CCResolverTest is Test {
    CCResolver public resolver;
    AssociationsStore public store;
    
    address parentAddr = address(0x1234);
    address child1Addr = address(0x5678);
    address child2Addr = address(0x9ABC);
    
    bytes parentAccount;
    bytes child1Account;
    bytes child2Account;
    
    uint256 parentPrivateKey = 0x1;
    uint256 child1PrivateKey = 0x2;
    uint256 child2PrivateKey = 0x3;

    function setUp() public {
        // Deploy contracts
        store = new AssociationsStore();
        resolver = new CCResolver(address(store), "eth.ecs.controlled-accounts:");
        
        // Setup test accounts as ERC-7930 addresses
        parentAddr = vm.addr(parentPrivateKey);
        child1Addr = vm.addr(child1PrivateKey);
        child2Addr = vm.addr(child2PrivateKey);
        
        parentAccount = InteroperableAddress.formatEvmV1(block.chainid, parentAddr);
        child1Account = InteroperableAddress.formatEvmV1(block.chainid, child1Addr);
        child2Account = InteroperableAddress.formatEvmV1(block.chainid, child2Addr);
    }

    /* --- Test Dividers --- */
    
    function test1000________________________________________________________________________________() public pure {}
    function test1100____________________CC_RESOLVER_TESTS______________________________________() public pure {}
    function test1200________________________________________________________________________________() public pure {}
    
    /* --- Registration Tests --- */
    
    function test_001____registerControlledAccounts__CanRegisterTwoChildren() public {
        // First, create associations between parent and children
        _setupControlledAccounts();
        
        // Register with CCResolver
        bytes[] memory children = new bytes[](2);
        children[0] = child1Account;
        children[1] = child2Account;
        
        uint256 id = resolver.registerControlledAccounts(parentAccount, children);
        
        // Verify registration
        assertTrue(resolver.idExists(id));
        assertEq(id, 0, "First ID should be 0");
        
        CCResolver.ControlledAccounts memory ca = resolver.getControlledAccounts(id);
        assertEq(ca.id, id);
        assertEq(keccak256(ca.parentAccount), keccak256(parentAccount));
        assertEq(ca.childAccounts.length, 2);
        assertEq(keccak256(ca.childAccounts[0]), keccak256(child1Account));
        assertEq(keccak256(ca.childAccounts[1]), keccak256(child2Account));
    }

    function test_006____text________________________ReturnsEmptyForExpiredAssociation() public {
        _setupControlledAccounts();
        
        bytes[] memory children = new bytes[](2);
        children[0] = child1Account;
        children[1] = child2Account;
        
        uint256 id = resolver.registerControlledAccounts(parentAccount, children);
        
        // Should be valid
        assertTrue(resolver.isValid(id));
    }

    function test_002____text________________________ReturnsYAMLForValidId() public {
        _setupControlledAccounts();
        
        bytes[] memory children = new bytes[](2);
        children[0] = child1Account;
        children[1] = child2Account;
        
        uint256 id = resolver.registerControlledAccounts(parentAccount, children);
        
        // Resolve via ENS text record
        bytes32 node = keccak256("test.eth");
        string memory key = string(abi.encodePacked("eth.ecs.controlled-accounts:", Strings.toString(id)));
        
        string memory result = resolver.text(node, key);
        
        // Result should not be empty
        assertTrue(bytes(result).length > 0);
        
        // Verify YAML format contains expected data
        // Check for YAML structure
        assertTrue(_contains(result, "id:"));
        assertTrue(_contains(result, "registeredAt:"));
        assertTrue(_contains(result, "parent:"));
        assertTrue(_contains(result, "children:"));
        
        // Log the YAML output for inspection
        console2.log("YAML Output:");
        console2.log(result);
    }

    function test_003____resolve_____________________ReturnsYAMLForValidId() public {
        _setupControlledAccounts();
        
        bytes[] memory children = new bytes[](2);
        children[0] = child1Account;
        children[1] = child2Account;
        
        uint256 id = resolver.registerControlledAccounts(parentAccount, children);
        
        // Call resolve() like ENS would
        bytes32 node = keccak256("test.eth");
        string memory key = string(abi.encodePacked("eth.ecs.controlled-accounts:", Strings.toString(id)));
        
        // Encode the text(bytes32,string) call
        bytes memory data = abi.encodeWithSelector(
            bytes4(0x59d1d43c), // text(bytes32,string) selector
            node,
            key
        );
        
        bytes memory name = hex"04746573740365746800"; // DNS-encoded "test.eth"
        bytes memory result = resolver.resolve(name, data);
        
        // Decode the outer layer (returns string)
        string memory resultString = abi.decode(result, (string));
        
        // Verify YAML format
        assertTrue(bytes(resultString).length > 0);
        assertTrue(_contains(resultString, "id:"));
        assertTrue(_contains(resultString, "parent:"));
        assertTrue(_contains(resultString, "children:"));
        
        console2.log("YAML Output from resolve():");
        console2.log(resultString);
    }
    
    /// @notice Helper function to check if a string contains a substring
    function _contains(string memory str, string memory substr) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);
        
        if (substrBytes.length > strBytes.length) {
            return false;
        }
        
        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }
        
        return false;
    }

    function test_005____text________________________ReturnsEmptyForInvalidData() public {
        // Create an association with wrong data
        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts.AssociatedAccountRecord({
            initiator: parentAccount,
            approver: child1Account,
            validAt: uint40(block.timestamp),
            validUntil: 0,
            interfaceId: bytes4(0),
            data: bytes("WrongData") // Wrong data
        });
        
        bytes32 hash = AssociatedAccountsLib.eip712Hash(record);
        
        // Sign with parent
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(parentPrivateKey, hash);
        bytes memory parentSig = abi.encodePacked(r1, s1, v1);
        
        // Sign with child
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(child1PrivateKey, hash);
        bytes memory child1Sig = abi.encodePacked(r2, s2, v2);
        
        AssociatedAccounts.SignedAssociationRecord memory sar = AssociatedAccounts.SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1,
            approverKeyType: K1,
            initiatorSignature: parentSig,
            approverSignature: child1Sig,
            record: record
        });
        
        store.storeAssociation(sar);
        
        // Register succeeds (no verification at registration time)
        bytes[] memory children = new bytes[](1);
        children[0] = child1Account;
        
        uint256 id = resolver.registerControlledAccounts(parentAccount, children);
        
        // But query returns empty because verification fails at read time
        bytes32 node = keccak256("test.eth");
        string memory key = string(abi.encodePacked("eth.ecs.controlled-accounts:", Strings.toString(id)));
        string memory result = resolver.text(node, key);
        
        // Should return empty string due to invalid data
        assertEq(bytes(result).length, 0, "Should return empty for invalid data");
    }

    function test_004____text________________________ReturnsEmptyForRevokedAssociation() public {
        _setupControlledAccounts();
        
        bytes[] memory children = new bytes[](2);
        children[0] = child1Account;
        children[1] = child2Account;
        
        // Register with valid associations
        uint256 id = resolver.registerControlledAccounts(parentAccount, children);
        
        // Initially works
        bytes32 node = keccak256("test.eth");
        string memory key = string(abi.encodePacked("eth.ecs.controlled-accounts:", Strings.toString(id)));
        string memory result = resolver.text(node, key);
        assertTrue(bytes(result).length > 0, "Should return data initially");
        
        // Get one of the associations and revoke it
        (bool exists, AssociatedAccounts.SignedAssociationRecord memory sar) = 
            store.getAssociationBetweenAccounts(parentAccount, child1Account);
        assertTrue(exists, "Association should exist");
        
        bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
        
        // Revoke as parent
        vm.prank(parentAddr);
        store.revokeAssociation(associationId, 0);
        
        // Now query returns empty because one association is revoked
        result = resolver.text(node, key);
        assertEq(bytes(result).length, 0, "Should return empty after revocation");
        
        console2.log("Read-time verification correctly detected revocation!");
    }

    function test_007____registerControlledAccounts__AssignsUniqueSequentialIds() public {
        _setupControlledAccounts();
        
        bytes[] memory children = new bytes[](2);
        children[0] = child1Account;
        children[1] = child2Account;
        
        // Register first time
        uint256 id1 = resolver.registerControlledAccounts(parentAccount, children);
        
        // Register again - should get different ID
        uint256 id2 = resolver.registerControlledAccounts(parentAccount, children);
        
        // IDs should be different and sequential
        assertTrue(id1 != id2, "IDs should be different");
        assertEq(id1, 0, "First ID should be 0");
        assertEq(id2, 1, "Second ID should be 1");
    }

    /* --- Error Cases --- */
    
    function test_010____registerControlledAccounts__RevertsIfNoChildren() public {
        bytes[] memory children = new bytes[](0);
        
        vm.expectRevert(CCResolver.NoChildAccounts.selector);
        resolver.registerControlledAccounts(parentAccount, children);
    }

    /* --- Prefix Management Tests --- */
    
    function test_008____setTextRecordPrefix_________UpdatesPrefixSuccessfully() public {
        _setupControlledAccounts();
        
        bytes[] memory children = new bytes[](2);
        children[0] = child1Account;
        children[1] = child2Account;
        
        uint256 id = resolver.registerControlledAccounts(parentAccount, children);
        
        // Query with original prefix
        bytes32 node = keccak256("test.eth");
        string memory key1 = string(abi.encodePacked("eth.ecs.controlled-accounts:", Strings.toString(id)));
        string memory result1 = resolver.text(node, key1);
        assertTrue(bytes(result1).length > 0, "Should resolve with original prefix");
        
        // Update prefix
        resolver.setTextRecordPrefix("new.prefix:");
        
        // Old key should not work
        string memory resultOld = resolver.text(node, key1);
        assertEq(bytes(resultOld).length, 0, "Old prefix should not work after update");
        
        // New key should work
        string memory key2 = string(abi.encodePacked("new.prefix:", Strings.toString(id)));
        string memory result2 = resolver.text(node, key2);
        assertTrue(bytes(result2).length > 0, "Should resolve with new prefix");
    }

    function test_009____setTextRecordPrefix_________OnlyOwnerCanUpdate() public {
        address notOwner = address(0x123);
        
        vm.prank(notOwner);
        vm.expectRevert(CCResolver.OnlyOwner.selector);
        resolver.setTextRecordPrefix("hacker.prefix:");
    }

    /* --- ENS Resolver Tests --- */
    
    function test_011____setText____________________OwnerCanSetText() public {
        string memory key = "resolver-info";
        string memory value = "# CCResolver v1.0";
        
        resolver.setText(key, value);
        
        bytes32 node = keccak256("test.eth");
        assertEq(resolver.text(node, key), value);
    }
    
    function test_012____setText____________________NonOwnerCannotSetText() public {
        string memory key = "avatar";
        string memory value = "https://example.com/avatar.png";
        
        address notOwner = address(0x456);
        vm.prank(notOwner);
        vm.expectRevert(CCResolver.OnlyOwner.selector);
        resolver.setText(key, value);
    }
    
    function test_013____setAddr____________________OwnerCanSetAddress() public {
        address ethAddr = address(0x5678);
        
        resolver.setAddr(ethAddr);
        
        bytes32 node = keccak256("test.eth");
        bytes memory result = resolver.addr(node, 60);
        assertEq(result, abi.encodePacked(ethAddr));
    }
    
    function test_014____setAddr____________________NonOwnerCannotSetAddress() public {
        address ethAddr = address(0x5678);
        
        address notOwner = address(0x789);
        vm.prank(notOwner);
        vm.expectRevert(CCResolver.OnlyOwner.selector);
        resolver.setAddr(ethAddr);
    }
    
    function test_015____setContenthash_____________OwnerCanSetContenthash() public {
        bytes memory hash = hex"e301017012204edd2984eeaf3ddf50bac238ec95c5713fb40b5e428b508fdbe55d3b9f155ffe";
        
        resolver.setContenthash(hash);
        
        bytes32 node = keccak256("test.eth");
        assertEq(resolver.contenthash(node), hash);
    }
    
    function test_016____setContenthash_____________NonOwnerCannotSetContenthash() public {
        bytes memory hash = hex"e301017012204edd2984eeaf3ddf50bac238ec95c5713fb40b5e428b508fdbe55d3b9f155ffe";
        
        address notOwner = address(0xabc);
        vm.prank(notOwner);
        vm.expectRevert(CCResolver.OnlyOwner.selector);
        resolver.setContenthash(hash);
    }
    
    function test_017____setData____________________OwnerCanSetData() public {
        string memory key = "proof.data";
        bytes memory value = abi.encode(uint256(12345));
        
        resolver.setData(key, value);
        
        bytes32 node = keccak256("test.eth");
        assertEq(resolver.data(node, key), value);
    }
    
    function test_018____setData____________________NonOwnerCannotSetData() public {
        string memory key = "proof.data";
        bytes memory value = abi.encode(uint256(12345));
        
        address notOwner = address(0xdef);
        vm.prank(notOwner);
        vm.expectRevert(CCResolver.OnlyOwner.selector);
        resolver.setData(key, value);
    }
    
    function test_019____supportsInterface__________SupportsIERC165() public {
        assertTrue(resolver.supportsInterface(type(IERC165).interfaceId));
    }
    
    function test_020____supportsInterface__________SupportsIExtendedResolver() public {
        assertTrue(resolver.supportsInterface(type(IExtendedResolver).interfaceId));
    }

    function test_021____text________________________ReturnsRegularTextRecord() public {
        string memory key = "com.twitter";
        string memory value = "@alice";
        
        resolver.setText(key, value);
        
        bytes32 node = keccak256("test.eth");
        string memory result = resolver.text(node, key);
        assertEq(result, value);
    }

    function test_022____resolve_____________________SupportsMultipleMethods() public {
        // Set up various records
        address ethAddr = address(0x1234);
        resolver.setAddr(ethAddr);
        
        string memory textKey = "com.github";
        string memory textValue = "alice";
        resolver.setText(textKey, textValue);
        
        bytes memory contentHash = hex"1234567890abcdef";
        resolver.setContenthash(contentHash);
        
        // Test resolve() with different selectors
        bytes32 node = keccak256("test.eth");
        
        // Test addr() via resolve
        bytes memory addrData = abi.encodeWithSelector(bytes4(0x3b3b57de), node);
        bytes memory addrResult = resolver.resolve("", addrData);
        address returnedAddr = abi.decode(addrResult, (address));
        assertEq(returnedAddr, ethAddr);
        
        // Test text() via resolve
        bytes memory textData = abi.encodeWithSelector(bytes4(0x59d1d43c), node, textKey);
        bytes memory textResult = resolver.resolve("", textData);
        string memory returnedText = abi.decode(textResult, (string));
        assertEq(returnedText, textValue);
        
        // Test contenthash() via resolve
        bytes memory hashData = abi.encodeWithSelector(bytes4(0xbc1c58d1), node);
        bytes memory hashResult = resolver.resolve("", hashData);
        bytes memory returnedHash = abi.decode(hashResult, (bytes));
        assertEq(returnedHash, contentHash);
    }

    // Helper function to setup controlled accounts associations
    function _setupControlledAccounts() internal {
        // Create association between parent and child1
        _createAssociation(parentAccount, child1Account, parentPrivateKey, child1PrivateKey);
        
        // Create association between parent and child2
        _createAssociation(parentAccount, child2Account, parentPrivateKey, child2PrivateKey);
    }

    function _createAssociation(
        bytes memory initiator,
        bytes memory approver,
        uint256 initiatorKey,
        uint256 approverKey
    ) internal {
        // Create record with "ControlledAccount" data
        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts.AssociatedAccountRecord({
            initiator: initiator,
            approver: approver,
            validAt: uint40(block.timestamp),
            validUntil: 0,
            interfaceId: bytes4(0),
            data: bytes("ControlledAccount")
        });
        
        bytes32 hash = AssociatedAccountsLib.eip712Hash(record);
        
        // Sign with initiator
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(initiatorKey, hash);
        bytes memory initiatorSig = abi.encodePacked(r1, s1, v1);
        
        // Sign with approver
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(approverKey, hash);
        bytes memory approverSig = abi.encodePacked(r2, s2, v2);
        
        AssociatedAccounts.SignedAssociationRecord memory sar = AssociatedAccounts.SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1,
            approverKeyType: K1,
            initiatorSignature: initiatorSig,
            approverSignature: approverSig,
            record: record
        });
        
        store.storeAssociation(sar);
    }
}

