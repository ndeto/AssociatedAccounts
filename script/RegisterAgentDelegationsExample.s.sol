// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {AssociationsStore} from "../src/AssociationsStore.sol";
import {AgentDelegationsResolver} from "../src/AgentDelegationsResolver.sol";
import {AssociatedAccounts} from "../src/AssociatedAccounts.sol";
import {AssociatedAccountsLib} from "../src/AssociatedAccountsLib.sol";
import {InteroperableAddress} from "../src/InteroperableAddresses.sol";
import "../src/KeyTypes.sol";

/// @notice Example script to register agent delegations.
/// @dev Creates ERC-8092 SARs for a delegator -> agent pair and registers them in AgentDelegationsResolver.
contract RegisterAgentDelegationsExampleScript is Script {
    using AssociatedAccountsLib for *;

    AssociationsStore public associationsStore;
    AgentDelegationsResolver public agentResolver;

    address public delegatorAddress;
    address public agent1Address;
    address public agent2Address;

    uint256 public delegatorPrivateKey;
    uint256 public agent1PrivateKey;
    uint256 public agent2PrivateKey;

    string public agent1MetadataJson;
    string public agent2MetadataJson;

    bytes4 internal constant AGENT_INTERFACE_ID = 0xa9ce26a1;

    function setUp() public {
        associationsStore = AssociationsStore(vm.envAddress("ASSOCIATIONS_STORE_ADDRESS"));
        agentResolver = AgentDelegationsResolver(vm.envAddress("AGENT_DELEGATIONS_RESOLVER_ADDRESS"));

        delegatorPrivateKey = vm.envUint("DELEGATOR_PRIVATE_KEY");
        agent1PrivateKey = vm.envUint("AGENT1_PRIVATE_KEY");
        agent2PrivateKey = vm.envUint("AGENT2_PRIVATE_KEY");

        delegatorAddress = vm.addr(delegatorPrivateKey);
        agent1Address = vm.addr(agent1PrivateKey);
        agent2Address = vm.addr(agent2PrivateKey);

        agent1MetadataJson = _envStringOr(
            "AGENT1_METADATA_JSON",
            '{"association":"Delegated Agent","name":"Agent One","description":"Demo agent 1","endpoints":[]}'
        );
        agent2MetadataJson = _envStringOr(
            "AGENT2_METADATA_JSON",
            '{"association":"Delegated Agent","name":"Agent Two","description":"Demo agent 2","endpoints":[]}'
        );

        console2.log("\n=== Agent Delegations Setup ===");
        console2.log("AssociationsStore:", address(associationsStore));
        console2.log("AgentResolver:", address(agentResolver));
        console2.log("Delegator:", delegatorAddress);
        console2.log("Agent #1:", agent1Address);
        console2.log("Agent #2:", agent2Address);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        uint256 chainId = block.chainid;

        vm.startBroadcast(deployerPrivateKey);

        bytes memory delegatorAccount = InteroperableAddress.formatEvmV1(chainId, delegatorAddress);
        bytes memory agent1Account = InteroperableAddress.formatEvmV1(chainId, agent1Address);
        bytes memory agent2Account = InteroperableAddress.formatEvmV1(chainId, agent2Address);

        console2.log("\n=== Step 1: Creating Agent Delegation SARs ===");
        bytes32[] memory associationIds = new bytes32[](2);
        associationIds[0] = _getOrCreateDelegation(
            delegatorAccount, agent1Account, delegatorPrivateKey, agent1PrivateKey, agent1MetadataJson
        );
        associationIds[1] = _getOrCreateDelegation(
            delegatorAccount, agent2Account, delegatorPrivateKey, agent2PrivateKey, agent2MetadataJson
        );

        console2.log("\n=== Step 2: Registering Delegations in Resolver ===");
        bytes[] memory agents = new bytes[](2);
        agents[0] = agent1Account;
        agents[1] = agent2Account;
        bytes32[] memory registered = agentResolver.registerDelegation(delegatorAccount, agents);

        vm.stopBroadcast();

        console2.log("\n=== Summary ===");
        console2.log("Delegator:", delegatorAddress);
        console2.log("Agent #1:", agent1Address);
        console2.log("Agent #2:", agent2Address);
        console2.log("AssociationsStore:", address(associationsStore));
        console2.log("AgentResolver:", address(agentResolver));
        console2.log("Text Record Prefix:", agentResolver.textRecordPrefix());
        for (uint256 i = 0; i < registered.length; i++) {
            console2.log("  Association ID:", _bytes32ToHex(registered[i]));
            console2.log(
                "  Hook key:",
                string.concat(agentResolver.textRecordPrefix(), _bytes32ToHex(registered[i]))
            );
        }
    }

    function _getOrCreateDelegation(
        bytes memory delegator,
        bytes memory agent,
        uint256 delegatorKey,
        uint256 agentKey,
        string memory metadataJson
    ) internal returns (bytes32 associationId) {
        (bool exists, AssociatedAccounts.SignedAssociationRecord memory existingSar) =
            associationsStore.getAssociationBetweenAccounts(delegator, agent);

        if (
            exists && keccak256(existingSar.record.initiator) == keccak256(delegator)
                && keccak256(existingSar.record.approver) == keccak256(agent)
                && existingSar.record.interfaceId == AGENT_INTERFACE_ID
        ) {
            associationId = AssociatedAccountsLib.associationIdFromSAR(existingSar);
            console2.log("  Reusing SAR with associationId:", _bytes32ToHex(associationId));
            return associationId;
        }

        AssociatedAccounts.AssociatedAccountRecord memory record =
            AssociatedAccounts.AssociatedAccountRecord({
                initiator: delegator,
                approver: agent,
                validAt: uint40(block.timestamp),
                validUntil: 0,
                interfaceId: AGENT_INTERFACE_ID,
                data: bytes(metadataJson)
            });

        bytes32 hash = AssociatedAccountsLib.eip712Hash(record);

        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(delegatorKey, hash);
        bytes memory delegatorSig = abi.encodePacked(r1, s1, v1);

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(agentKey, hash);
        bytes memory agentSig = abi.encodePacked(r2, s2, v2);

        AssociatedAccounts.SignedAssociationRecord memory sar = AssociatedAccounts.SignedAssociationRecord({
            revokedAt: 0,
            initiatorKeyType: K1,
            approverKeyType: K1,
            initiatorSignature: delegatorSig,
            approverSignature: agentSig,
            record: record
        });

        associationsStore.storeAssociation(sar);
        associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
        console2.log("  Created SAR with associationId:", _bytes32ToHex(associationId));
    }

    function _envStringOr(string memory key, string memory fallbackValue) internal view returns (string memory) {
        try vm.envString(key) returns (string memory value) {
            return value;
        } catch {
            return fallbackValue;
        }
    }

    function _bytes32ToHex(bytes32 value) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(66);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 32; i++) {
            uint8 b = uint8(value[i]);
            str[2 + i * 2] = alphabet[b >> 4];
            str[3 + i * 2] = alphabet[b & 0x0f];
        }
        return string(str);
    }
}
