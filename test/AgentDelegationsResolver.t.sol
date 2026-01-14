// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {AgentDelegationsResolver} from "src/AgentDelegationsResolver.sol";
import {AssociationsStore} from "src/AssociationsStore.sol";
import {AssociatedAccounts} from "src/AssociatedAccounts.sol";
import {AssociatedAccountsLib} from "src/AssociatedAccountsLib.sol";
import {InteroperableAddress} from "src/InteroperableAddresses.sol";
import {K1} from "src/KeyTypes.sol";

contract AgentDelegationsResolverTest is Test {
    using AssociatedAccountsLib for *;

    uint256 internal delegatorKey = 0xA11CE;
    address internal delegatorAddr = vm.addr(delegatorKey);
    uint256 internal agentKey = 0xB0B;
    address internal agentAddr = vm.addr(agentKey);

    bytes4 internal constant AGENT_INTERFACE_ID = 0xa9ce26a1;

    AssociationsStore internal store;
    AgentDelegationsResolver internal resolver;

    string internal constant JSON_PAYLOAD =
        '{"association":"Delegated Agent","name":"Orbit AI","description":"Execution agent","endpoints":[{"name":"A2A","endpoint":"https://agent.example/.well-known/agent-card.json"}]}';

    function setUp() public {
        store = new AssociationsStore();
        resolver = new AgentDelegationsResolver(address(store), "eth.ecs.agent-delegations:");
    }

    function testTextReturnsDelegationJSON() public {
        (,, bytes32 associationId) = _storeDelegation(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        bytes32[] memory associationIds = new bytes32[](1);
        associationIds[0] = associationId;

        uint256 delegationId = resolver.registerDelegations(associationIds);
        string memory key = string.concat("eth.ecs.agent-delegations:", vm.toString(delegationId));
        string memory response = resolver.text(bytes32(0), key);

        assertTrue(bytes(response).length > 0, "Response empty");
        assertTrue(_contains(response, '"delegationId":'), "Missing delegation id");
        assertTrue(_contains(response, '"delegations":['), "Missing delegations array");
        assertTrue(_contains(response, '"associationId":"0x'), "Missing association id");
        assertTrue(_contains(response, '"payloadHex":"0x'), "Missing payload hex");
    }

    function testTextRevertsWhenInterfaceIdMismatch() public {
        (,, bytes32 associationId) = _storeDelegation(bytes4(0x12345678), JSON_PAYLOAD);
        bytes32[] memory associationIds = new bytes32[](1);
        associationIds[0] = associationId;

        vm.expectRevert(
            abi.encodeWithSelector(AgentDelegationsResolver.InvalidInterfaceId.selector, bytes4(0x12345678))
        );
        resolver.registerDelegations(associationIds);
    }

    function testRegisterAndResolveDelegationGroup() public {
        (,, bytes32 associationId1) = _storeDelegation(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        (,, bytes32 associationId2) =
            _storeSecondDelegation('{"association":"Delegated Agent","name":"Second","description":"Another","endpoints":[]}');
        bytes32[] memory associationIds = new bytes32[](2);
        associationIds[0] = associationId1;
        associationIds[1] = associationId2;

        uint256 delegationId = resolver.registerDelegations(associationIds);
        assertTrue(delegationId >= 0);
        string memory key = string.concat("eth.ecs.agent-delegations:", vm.toString(delegationId));
        string memory response = resolver.text(bytes32(0), key);
        assertTrue(_contains(response, _bytes32ToHex(associationId1)), "Missing first association id");
        assertTrue(_contains(response, _bytes32ToHex(associationId2)), "Missing second association id");
    }

    function testRegisterSingleDelegationGroup() public {
        (,, bytes32 associationId) = _storeDelegation(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        bytes32[] memory associationIds = new bytes32[](1);
        associationIds[0] = associationId;
        resolver.registerDelegations(associationIds);
        string memory key = string.concat("eth.ecs.agent-delegations:", "0");
        string memory response = resolver.text(bytes32(0), key);
        assertTrue(_contains(response, _bytes32ToHex(associationId)), "Missing association id");
    }

    function testRegisterEmptyReverts() public {
        bytes32[] memory associationIds = new bytes32[](0);
        vm.expectRevert(AgentDelegationsResolver.NoAssociationIds.selector);
        resolver.registerDelegations(associationIds);
    }

    function testRegisterMixedDelegatorsReverts() public {
        (,, bytes32 associationId1) = _storeDelegation(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        (,, bytes32 associationId2) =
            _storeDelegationWithDelegator(0xBEEF, AGENT_INTERFACE_ID, JSON_PAYLOAD);

        bytes32[] memory associationIds = new bytes32[](2);
        associationIds[0] = associationId1;
        associationIds[1] = associationId2;

        vm.expectRevert(abi.encodeWithSelector(AgentDelegationsResolver.WrongAccountRoles.selector, associationId2));
        resolver.registerDelegations(associationIds);
    }

    function testMissingDelegationReturnsEmpty() public {
        string memory key = string.concat("eth.ecs.agent-delegations:", "9999");
        assertEq(resolver.text(bytes32(0), key), "");
        assertEq(resolver.data(bytes32(0), key), bytes(""));
    }

    function testMalformedKeyReturnsEmpty() public {
        string memory key = "eth.ecs.agent-delegations:abc";
        assertEq(resolver.text(bytes32(0), key), "");
        assertEq(resolver.data(bytes32(0), key), bytes(""));
    }

    function testDataReturnsEncodedPayloads() public {
        (,, bytes32 associationId) = _storeDelegation(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        bytes32[] memory associationIds = new bytes32[](1);
        associationIds[0] = associationId;
        uint256 delegationId = resolver.registerDelegations(associationIds);

        string memory key = string.concat("eth.ecs.agent-delegations:", vm.toString(delegationId));
        bytes memory payload = resolver.data(bytes32(0), key);
        bytes[] memory expected = new bytes[](1);
        expected[0] = bytes(JSON_PAYLOAD);
        assertEq(payload, abi.encode(expected));
    }

    function testInvalidAssociationReturnsEmpty() public {
        (,, bytes32 associationId) = _storeDelegationWithChainId(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        bytes32[] memory associationIds = new bytes32[](1);
        associationIds[0] = associationId;
        uint256 delegationId = resolver.registerDelegations(associationIds);

        vm.prank(delegatorAddr);
        store.revokeAssociation(associationId, 0);

        string memory key = string.concat("eth.ecs.agent-delegations:", vm.toString(delegationId));
        assertEq(resolver.text(bytes32(0), key), "");
        assertEq(resolver.data(bytes32(0), key), bytes(""));
    }

    function _storeSecondDelegation(string memory jsonData)
        internal
        returns (bytes memory delegator, bytes memory agent, bytes32 associationId)
    {
        delegator = InteroperableAddress.formatEvmV1(delegatorAddr);
        agent = InteroperableAddress.formatEvmV1(vm.addr(agentKey + 1));

        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts.AssociatedAccountRecord({
            initiator: delegator,
            approver: agent,
            validAt: uint40(block.timestamp),
            validUntil: 0,
            interfaceId: AGENT_INTERFACE_ID,
            data: bytes(jsonData)
        });

        bytes memory delegatorSignature = _signRecord(record, delegatorKey);
        bytes memory agentSignature = _signRecord(record, agentKey + 1);

        AssociatedAccounts.SignedAssociationRecord memory sar = AssociatedAccounts.SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1,
            approverKeyType: K1,
            initiatorSignature: delegatorSignature,
            approverSignature: agentSignature,
            record: record
        });

        store.storeAssociation(sar);
        associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
    }

    function _storeDelegation(bytes4 interfaceId, string memory jsonData)
        internal
        returns (bytes memory delegator, bytes memory agent, bytes32 associationId)
    {
        delegator = InteroperableAddress.formatEvmV1(delegatorAddr);
        agent = InteroperableAddress.formatEvmV1(agentAddr);

        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts.AssociatedAccountRecord({
            initiator: delegator,
            approver: agent,
            validAt: uint40(block.timestamp),
            validUntil: 0,
            interfaceId: interfaceId,
            data: bytes(jsonData)
        });

        bytes memory delegatorSignature = _signRecord(record, delegatorKey);
        bytes memory agentSignature = _signRecord(record, agentKey);

        AssociatedAccounts.SignedAssociationRecord memory sar = AssociatedAccounts.SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1,
            approverKeyType: K1,
            initiatorSignature: delegatorSignature,
            approverSignature: agentSignature,
            record: record
        });

        store.storeAssociation(sar);
        associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
    }

    function _storeDelegationWithChainId(bytes4 interfaceId, string memory jsonData)
        internal
        returns (bytes memory delegator, bytes memory agent, bytes32 associationId)
    {
        delegator = InteroperableAddress.formatEvmV1(block.chainid, delegatorAddr);
        agent = InteroperableAddress.formatEvmV1(block.chainid, agentAddr);

        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts.AssociatedAccountRecord({
            initiator: delegator,
            approver: agent,
            validAt: uint40(block.timestamp),
            validUntil: 0,
            interfaceId: interfaceId,
            data: bytes(jsonData)
        });

        bytes memory delegatorSignature = _signRecord(record, delegatorKey);
        bytes memory agentSignature = _signRecord(record, agentKey);

        AssociatedAccounts.SignedAssociationRecord memory sar = AssociatedAccounts.SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1,
            approverKeyType: K1,
            initiatorSignature: delegatorSignature,
            approverSignature: agentSignature,
            record: record
        });

        store.storeAssociation(sar);
        associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
    }

    function _storeDelegationWithDelegator(uint256 delegatorKeyOverride, bytes4 interfaceId, string memory jsonData)
        internal
        returns (bytes memory delegator, bytes memory agent, bytes32 associationId)
    {
        address delegatorAddrOverride = vm.addr(delegatorKeyOverride);
        delegator = InteroperableAddress.formatEvmV1(delegatorAddrOverride);
        agent = InteroperableAddress.formatEvmV1(agentAddr);

        AssociatedAccounts.AssociatedAccountRecord memory record = AssociatedAccounts.AssociatedAccountRecord({
            initiator: delegator,
            approver: agent,
            validAt: uint40(block.timestamp),
            validUntil: 0,
            interfaceId: interfaceId,
            data: bytes(jsonData)
        });

        bytes memory delegatorSignature = _signRecord(record, delegatorKeyOverride);
        bytes memory agentSignature = _signRecord(record, agentKey);

        AssociatedAccounts.SignedAssociationRecord memory sar = AssociatedAccounts.SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1,
            approverKeyType: K1,
            initiatorSignature: delegatorSignature,
            approverSignature: agentSignature,
            record: record
        });

        store.storeAssociation(sar);
        associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
    }


    function _signRecord(AssociatedAccounts.AssociatedAccountRecord memory record, uint256 key)
        internal
        view
        returns (bytes memory)
    {
        bytes32 hash = AssociatedAccountsLib.eip712Hash(record);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        return abi.encodePacked(r, s, v);
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) return true;
        }
        return false;
    }

    function _bytes32ToHex(bytes32 value) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            uint8 byteValue = uint8(value[i]);
            str[i * 2] = alphabet[byteValue >> 4];
            str[i * 2 + 1] = alphabet[byteValue & 0x0f];
        }
        return string(abi.encodePacked("0x", str));
    }
}
