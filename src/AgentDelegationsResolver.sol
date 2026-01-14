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

    struct DelegationGroup {
        bytes delegator;
        address registrant;
        uint256 registeredAt;
    }

    AssociationsStore public immutable associationsStore;
    string public textRecordPrefix;
    address public owner;
    mapping(bytes32 => Delegation) private delegations;
    mapping(bytes32 => bool) public delegationExists;
    uint256 public nextDelegationId;
    mapping(uint256 => DelegationGroup) private delegationGroups;
    mapping(uint256 => bytes32[]) private delegationGroupAssociationIds;

    event DelegationRegistered(bytes32 indexed associationId, bytes delegator, bytes agent, address indexed registrar);
    event DelegationGroupRegistered(
        uint256 indexed delegationId, bytes delegator, bytes32[] associationIds, address indexed registrant
    );
    event TextRecordPrefixUpdated(string newPrefix);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NoAssociationIds();
    error DelegationAlreadyRegistered(bytes32 associationId);
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

    /// @notice Register a batch of association ids and return the delegationId used in text record keys.
    function registerDelegations(bytes32[] calldata associationIds) external returns (uint256 delegationId) {
        if (associationIds.length == 0) revert NoAssociationIds();

        delegationId = nextDelegationId++;
        DelegationGroup storage group = delegationGroups[delegationId];
        group.registrant = msg.sender;
        group.registeredAt = block.timestamp;

        bytes32[] storage groupAssociations = delegationGroupAssociationIds[delegationId];
        bytes memory groupDelegator;

        for (uint256 i = 0; i < associationIds.length; i++) {
            bytes32 storedId = _storeDelegation(associationIds[i]);
            Delegation storage delegation = delegations[storedId];

            if (i == 0) {
                groupDelegator = delegation.delegator;
                group.delegator = groupDelegator;
            } else if (keccak256(delegation.delegator) != keccak256(groupDelegator)) {
                revert WrongAccountRoles(storedId);
            }

            groupAssociations.push(storedId);
        }

        bytes32[] memory emittedIds = new bytes32[](groupAssociations.length);
        for (uint256 i = 0; i < groupAssociations.length; i++) {
            emittedIds[i] = groupAssociations[i];
        }

        emit DelegationGroupRegistered(delegationId, group.delegator, emittedIds, msg.sender);
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

    /// @dev Cache association metadata for later group resolution.
    function _storeDelegation(bytes32 associationId) internal returns (bytes32) {
        AssociatedAccounts.SignedAssociationRecord memory sar = _fetchAssociationForRegistration(associationId);
        if (delegationExists[associationId]) revert DelegationAlreadyRegistered(associationId);

        bytes memory delegator = sar.record.initiator;
        bytes memory agent = sar.record.approver;

        Delegation storage delegation = delegations[associationId];
        delegation.associationId = associationId;
        delegation.delegator = delegator;
        delegation.agent = agent;
        delegation.registeredAt = block.timestamp;

        delegationExists[associationId] = true;

        emit DelegationRegistered(associationId, delegator, agent, msg.sender);
        return associationId;
    }

    /// @dev Resolve a text key into a delegation group envelope JSON.
    function _resolveText(string memory key) internal view returns (string memory) {
        (bool parsed, uint256 delegationId) = _parseDelegationIdFromKey(key);
        if (!parsed) {
            return "";
        }
        (bool success, string memory envelope,) = _resolveDelegationGroup(delegationId);
        return success ? envelope : "";
    }

    /// @dev Resolve a text key into ABI-encoded payloads for the delegation group.
    function _resolveData(string memory key) internal view returns (bytes memory) {
        (bool parsed, uint256 delegationId) = _parseDelegationIdFromKey(key);
        if (!parsed) {
            return bytes("");
        }
        (bool success,, bytes memory payload) = _resolveDelegationGroup(delegationId);
        return success ? payload : bytes("");
    }

    /// @dev Parse the delegationId from "<prefix><numericId>" text record keys.
    function _parseDelegationIdFromKey(string memory key) internal view returns (bool, uint256) {
        bytes memory keyBytes = bytes(key);
        bytes memory prefixBytes = bytes(textRecordPrefix);

        if (keyBytes.length <= prefixBytes.length) {
            return (false, 0);
        }

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (keyBytes[i] != prefixBytes[i]) {
                return (false, 0);
            }
        }

        uint256 result = 0;
        bool hasDigits = false;
        for (uint256 i = prefixBytes.length; i < keyBytes.length; i++) {
            uint8 digit = uint8(keyBytes[i]);
            if (digit >= 48 && digit <= 57) {
                result = result * 10 + (digit - 48);
                hasDigits = true;
            } else {
                return (false, 0);
            }
        }
        if (!hasDigits) return (false, 0);
        return (true, result);
    }

    /// @dev Resolve a delegation group by validating each association id and building the JSON envelope.
    function _resolveDelegationGroup(uint256 delegationId)
        internal
        view
        returns (bool success, string memory envelope, bytes memory payload)
    {
        DelegationGroup storage group = delegationGroups[delegationId];
        if (group.delegator.length == 0) {
            return (false, "", bytes(""));
        }

        bytes32[] storage groupAssociations = delegationGroupAssociationIds[delegationId];
        if (groupAssociations.length == 0) {
            return (false, "", bytes(""));
        }

        bytes[] memory payloads = new bytes[](groupAssociations.length);
        bytes memory entriesJson = bytes("[");

        for (uint256 i = 0; i < groupAssociations.length; i++) {
            bytes32 associationId = groupAssociations[i];
            Delegation storage delegation = delegations[associationId];
            (bool valid, AssociatedAccounts.SignedAssociationRecord memory sar) =
                _loadAndValidateAssociation(associationId, delegation.delegator, delegation.agent);

            if (!valid) {
                return (false, "", bytes(""));
            }

            bytes memory entryPayload = sar.record.data;
            payloads[i] = entryPayload;

            entriesJson = abi.encodePacked(
                entriesJson,
                i == 0 ? "" : ",",
                '{"associationId":"0x',
                _bytesToHexString(abi.encodePacked(associationId)),
                '","agent":"0x',
                _bytesToHexString(delegation.agent),
                '","payloadLen":',
                Strings.toString(entryPayload.length),
                ',"payloadHash":"0x',
                _bytesToHexString(abi.encodePacked(keccak256(entryPayload))),
                '","payloadHex":"0x',
                _bytesToHexString(entryPayload),
                '"}'
            );
        }

        entriesJson = abi.encodePacked(entriesJson, "]");

        envelope = string(
            abi.encodePacked(
                '{"version":1,"delegationId":',
                Strings.toString(delegationId),
                ',"delegator":"0x',
                _bytesToHexString(group.delegator),
                '","registeredAt":',
                Strings.toString(group.registeredAt),
                ',"delegations":',
                entriesJson,
                "}"
            )
        );

        payload = abi.encode(payloads);
        return (true, envelope, payload);
    }

    /// @dev Fetch and validate the SAR during registration.
    function _fetchAssociationForRegistration(bytes32 associationId)
        internal
        view
        returns (AssociatedAccounts.SignedAssociationRecord memory sar)
    {
        sar = associationsStore.getAssociation(associationId);
        if (sar.record.interfaceId != DELEGATED_AGENT_INTERFACE_ID) {
            revert InvalidInterfaceId(sar.record.interfaceId);
        }
        return sar;
    }

    /// @dev Load and validate SARs on read to ensure current validity.
    function _loadAndValidateAssociation(bytes32 associationId, bytes memory delegator, bytes memory agent)
        internal
        view
        returns (bool, AssociatedAccounts.SignedAssociationRecord memory sar)
    {
        AssociatedAccounts.SignedAssociationRecord memory stored;
        try associationsStore.getAssociation(associationId) returns (
            AssociatedAccounts.SignedAssociationRecord memory fetched
        ) {
            stored = fetched;
        } catch {
            return (false, stored);
        }
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

    /// @dev Convert bytes to lowercase hex without 0x prefix.
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
