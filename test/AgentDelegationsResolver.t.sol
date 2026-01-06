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
        (bytes memory delegator, bytes memory agent) = _storeDelegation(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        bytes[] memory agents = new bytes[](1);
        agents[0] = agent;
        bytes32[] memory associationIds = resolver.registerDelegation(delegator, agents);

        string memory key = string.concat("eth.ecs.agent-delegations:", _bytes32ToHex(associationIds[0]));
        string memory response = resolver.text(bytes32(0), key);

        assertTrue(bytes(response).length > 0, "Response empty");
        assertTrue(_contains(response, '"associationId":"0x'), "Missing association id");
        assertTrue(_contains(response, '"payload":{"association":"Delegated Agent"'), "Missing payload");
    }

    function testTextRevertsWhenInterfaceIdMismatch() public {
        (bytes memory delegator, bytes memory agent) = _storeDelegation(bytes4(0x12345678), JSON_PAYLOAD);
        bytes[] memory agents = new bytes[](1);
        agents[0] = agent;

        vm.expectRevert(
            abi.encodeWithSelector(AgentDelegationsResolver.InvalidInterfaceId.selector, bytes4(0x12345678))
        );
        resolver.registerDelegation(delegator, agents);
    }

    function testDelegationEnumerationPerDelegator() public {
        (bytes memory delegator, bytes memory agent) = _storeDelegation(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        bytes memory agent2 =
            _storeSecondDelegation('{"association":"Delegated Agent","name":"Second","description":"Another","endpoints":[]}');
        bytes[] memory agents = new bytes[](2);
        agents[0] = agent;
        agents[1] = agent2;

        bytes32[] memory newIds = resolver.registerDelegation(delegator, agents);
        assertEq(newIds.length, 2);
        assertTrue(newIds[0] != bytes32(0));
        assertTrue(newIds[1] != bytes32(0));

        bytes32[] memory ids = resolver.getDelegationIds(delegator);
        assertEq(ids.length, 2);
        assertEq(ids[0], newIds[0]);
        assertEq(ids[1], newIds[1]);
    }

    function testGetDelegationIdsForAgent() public {
        (bytes memory delegator, bytes memory agent) = _storeDelegation(AGENT_INTERFACE_ID, JSON_PAYLOAD);
        bytes[] memory agents = new bytes[](1);
        agents[0] = agent;
        bytes32[] memory registeredIds = resolver.registerDelegation(delegator, agents);

        bytes32[] memory ids = resolver.getDelegationIdsForAgent(agent);
        assertEq(ids.length, 1);
        assertEq(ids[0], registeredIds[0]);
    }

    function _storeSecondDelegation(string memory jsonData) internal returns (bytes memory agent) {
        bytes memory delegator = InteroperableAddress.formatEvmV1(delegatorAddr);
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
    }

    function _storeDelegation(bytes4 interfaceId, string memory jsonData)
        internal
        returns (bytes memory delegator, bytes memory agent)
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
