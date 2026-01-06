// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AssociationsStore} from "./AssociationsStore.sol";
import {AssociatedAccounts} from "./AssociatedAccounts.sol";
import {AssociatedAccountsLib} from "./AssociatedAccountsLib.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

interface IExtendedResolver {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/// @title AgentDelegationsResolver
/// @notice ENS-compatible resolver that exposes delegated agent relationships backed by ERC-8092 SARs.
contract AgentDelegationsResolver is IExtendedResolver, IERC165 {
    using AssociatedAccountsLib for *;

    bytes4 private constant TEXT_SELECTOR = 0x59d1d43c;
    bytes4 private constant DATA_SELECTOR = 0xd700ff33;
    bytes4 public constant DELEGATED_AGENT_INTERFACE_ID = 0xa9ce26a1;

    struct Delegation {
        bytes32 associationId;
        bytes delegator;
        bytes agent;
        uint256 registeredAt;
    }

    AssociationsStore public immutable associationsStore;
    string public textRecordPrefix;
    address public owner;
    mapping(bytes32 => Delegation) private delegations;
    mapping(bytes32 => bool) public delegationExists;
    mapping(bytes32 => bytes32[]) private delegatorToAssociationIds;
    mapping(bytes32 => bytes32[]) private agentToAssociationIds;

    event DelegationRegistered(bytes32 indexed associationId, bytes delegator, bytes agent, address indexed registrar);
    event TextRecordPrefixUpdated(string newPrefix);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error EmptyDelegation();
    error NoAgentsProvided();
    error DelegationNotFound(bytes32 associationId);
    error AssociationRecordMissing(bytes32 delegatorHash, bytes32 agentHash);
    error DelegationAlreadyRegistered(bytes32 associationId);
    error InvalidAssociation(bytes32 associationId);
    error WrongAccountRoles(bytes32 associationId);
    error InvalidInterfaceId(bytes4 actual);
    error OnlyOwner();

    constructor(address _associationsStore, string memory _textRecordPrefix) {
        associationsStore = AssociationsStore(_associationsStore);
        textRecordPrefix = _textRecordPrefix;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    function registerDelegation(bytes calldata delegator, bytes[] calldata agents)
        external
        returns (bytes32[] memory ids)
    {
        if (delegator.length == 0) revert EmptyDelegation();
        if (agents.length == 0) revert NoAgentsProvided();

        ids = new bytes32[](agents.length);
        for (uint256 i = 0; i < agents.length; i++) {
            if (agents[i].length == 0) revert EmptyDelegation();
            ids[i] = _storeDelegation(delegator, agents[i]);
        }
    }

    function getDelegation(bytes32 associationId) external view returns (Delegation memory) {
        if (!delegationExists[associationId]) revert DelegationNotFound(associationId);
        return delegations[associationId];
    }

    function getDelegationIds(bytes calldata delegator) external view returns (bytes32[] memory) {
        return delegatorToAssociationIds[keccak256(delegator)];
    }

    function getDelegationIdsForAgent(bytes calldata agent) external view returns (bytes32[] memory) {
        return agentToAssociationIds[keccak256(agent)];
    }

    function getAgentsForDelegator(bytes calldata delegator) external view returns (bytes[] memory agents) {
        bytes32[] storage assocIds = delegatorToAssociationIds[keccak256(delegator)];
        agents = new bytes[](assocIds.length);
        for (uint256 i = 0; i < assocIds.length; i++) {
            if (!delegationExists[assocIds[i]]) continue;
            agents[i] = delegations[assocIds[i]].agent;
        }
    }

    function getDelegatorsForAgent(bytes calldata agent) external view returns (bytes[] memory delegators) {
        bytes32[] storage assocIds = agentToAssociationIds[keccak256(agent)];
        delegators = new bytes[](assocIds.length);
        for (uint256 i = 0; i < assocIds.length; i++) {
            if (!delegationExists[assocIds[i]]) continue;
            delegators[i] = delegations[assocIds[i]].delegator;
        }
    }

    function setTextRecordPrefix(string calldata newPrefix) external onlyOwner {
        textRecordPrefix = newPrefix;
        emit TextRecordPrefixUpdated(newPrefix);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function resolve(bytes calldata, bytes calldata callData) external view returns (bytes memory) {
        bytes4 selector = bytes4(callData[:4]);

        if (selector == TEXT_SELECTOR) {
            (, string memory key) = abi.decode(callData[4:], (bytes32, string));
            string memory value = _resolveText(key);
            return abi.encode(value);
        }

        if (selector == DATA_SELECTOR) {
            (, string memory key) = abi.decode(callData[4:], (bytes32, string));
            bytes memory payload = _resolveData(key);
            return abi.encode(payload);
        }

        return abi.encode("");
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IExtendedResolver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function text(bytes32, string calldata key) external view returns (string memory) {
        return _resolveText(key);
    }

    function data(bytes32, string calldata key) external view returns (bytes memory) {
        return _resolveData(key);
    }

    function _storeDelegation(bytes calldata delegator, bytes calldata agent) internal returns (bytes32 associationId) {
        AssociatedAccounts.SignedAssociationRecord memory sar = _fetchAssociationForRegistration(delegator, agent);
        associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
        if (delegationExists[associationId]) revert DelegationAlreadyRegistered(associationId);

        Delegation storage delegation = delegations[associationId];
        delegation.associationId = associationId;
        delegation.delegator = delegator;
        delegation.agent = agent;
        delegation.registeredAt = block.timestamp;

        delegationExists[associationId] = true;
        delegatorToAssociationIds[keccak256(delegator)].push(associationId);
        agentToAssociationIds[keccak256(agent)].push(associationId);

        emit DelegationRegistered(associationId, delegator, agent, msg.sender);
    }

    function _resolveText(string memory key) internal view returns (string memory) {
        bytes32 associationId = _parseAssociationIdFromKey(key);
        if (associationId == bytes32(0)) {
            return "";
        }
        (bool success, string memory envelope,) = _resolveDelegation(associationId);
        return success ? envelope : "";
    }

    function _resolveData(string memory key) internal view returns (bytes memory) {
        bytes32 associationId = _parseAssociationIdFromKey(key);
        if (associationId == bytes32(0)) {
            return bytes("");
        }
        (bool success,, bytes memory payload) = _resolveDelegation(associationId);
        return success ? payload : bytes("");
    }

    function _parseAssociationIdFromKey(string memory key) internal view returns (bytes32 associationId) {
        bytes memory keyBytes = bytes(key);
        bytes memory prefixBytes = bytes(textRecordPrefix);

        if (keyBytes.length <= prefixBytes.length) {
            return bytes32(0);
        }

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (keyBytes[i] != prefixBytes[i]) {
                return bytes32(0);
            }
        }

        uint256 startIndex = prefixBytes.length;
        if (keyBytes.length <= startIndex + 2) {
            return bytes32(0);
        }
        if (keyBytes[startIndex] != '0' || keyBytes[startIndex + 1] != 'x') {
            return bytes32(0);
        }

        uint256 hexLen = keyBytes.length - (startIndex + 2);
        if (hexLen != 64) return bytes32(0);

        bytes32 result;
        for (uint256 i = 0; i < 64; i++) {
            uint8 charCode = uint8(keyBytes[startIndex + 2 + i]);
            uint8 value;
            if (charCode >= 48 && charCode <= 57) {
                value = charCode - 48;
            } else if (charCode >= 97 && charCode <= 102) {
                value = charCode - 87;
            } else if (charCode >= 65 && charCode <= 70) {
                value = charCode - 55;
            } else {
                return bytes32(0);
            }
            result = bytes32((uint256(result) << 4) | uint256(value));
        }
        associationId = result;
    }

    function _resolveDelegation(bytes32 associationId)
        internal
        view
        returns (bool success, string memory envelope, bytes memory payload)
    {
        if (!delegationExists[associationId]) {
            return (false, "", bytes(""));
        }

        Delegation storage delegation = delegations[associationId];
        (bool valid, AssociatedAccounts.SignedAssociationRecord memory sar) =
            _loadAndValidateAssociation(delegation.delegator, delegation.agent);

        if (!valid) {
            return (false, "", bytes(""));
        }

        payload = sar.record.data;
        envelope = _formatEnvelope(associationId, delegation.delegator, delegation.agent, payload);
        return (true, envelope, payload);
    }

    function _fetchAssociationForRegistration(bytes memory delegator, bytes memory agent)
        internal
        view
        returns (AssociatedAccounts.SignedAssociationRecord memory sar)
    {
        (bool exists, AssociatedAccounts.SignedAssociationRecord memory stored) =
            associationsStore.getAssociationBetweenAccounts(delegator, agent);

        if (!exists) {
            revert AssociationRecordMissing(keccak256(delegator), keccak256(agent));
        }

        if (
            keccak256(stored.record.initiator) != keccak256(delegator)
                || keccak256(stored.record.approver) != keccak256(agent)
        ) {
            bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(stored);
            revert WrongAccountRoles(associationId);
        }

        if (stored.record.interfaceId != DELEGATED_AGENT_INTERFACE_ID) {
            revert InvalidInterfaceId(stored.record.interfaceId);
        }

        return stored;
    }

    function _loadAndValidateAssociation(bytes memory delegator, bytes memory agent)
        internal
        view
        returns (bool, AssociatedAccounts.SignedAssociationRecord memory sar)
    {
        (bool exists, AssociatedAccounts.SignedAssociationRecord memory stored) =
            associationsStore.getAssociationBetweenAccounts(delegator, agent);

        if (!exists) {
            return (false, stored);
        }

        bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(stored);

        if (!stored.validateAssociatedAccount()) {
            return (false, stored);
        }

        if (
            keccak256(stored.record.initiator) != keccak256(delegator)
                || keccak256(stored.record.approver) != keccak256(agent)
        ) {
            return (false, stored);
        }

        if (stored.record.interfaceId != DELEGATED_AGENT_INTERFACE_ID) {
            return (false, stored);
        }

        return (true, stored);
    }

    function _formatEnvelope(bytes32 associationId, bytes memory delegator, bytes memory agent, bytes memory payload)
        internal
        pure
        returns (string memory)
    {
        string memory associationIdHex =
            string(abi.encodePacked("0x", _bytesToHexString(abi.encodePacked(associationId))));
        string memory delegatorHex = string(abi.encodePacked("0x", _bytesToHexString(delegator)));
        string memory agentHex = string(abi.encodePacked("0x", _bytesToHexString(agent)));
        string memory payloadHex = string(abi.encodePacked("0x", _bytesToHexString(payload)));
        string memory payloadHash = string(abi.encodePacked("0x", _bytesToHexString(abi.encodePacked(keccak256(payload)))));

        return string(
            abi.encodePacked(
                '{"version":1,"associationId":"',
                associationIdHex,
                '","delegator":"',
                delegatorHex,
                '","agent":"',
                agentHex,
                '","payloadLen":',
                Strings.toString(payload.length),
                ',"payloadHash":"',
                payloadHash,
                '","payloadHex":"',
                payloadHex,
                '"}'
            )
        );
    }

    function _bytesToHexString(bytes memory input) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(input.length * 2);
        for (uint256 i = 0; i < input.length; i++) {
            str[i * 2] = alphabet[uint8(input[i] >> 4)];
            str[i * 2 + 1] = alphabet[uint8(input[i] & 0x0f)];
        }
        return string(str);
    }

}
