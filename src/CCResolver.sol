// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AssociationsStore} from "./AssociationsStore.sol";
import {AssociatedAccounts} from "./AssociatedAccounts.sol";
import {AssociatedAccountsLib} from "./AssociatedAccountsLib.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";

/// @notice ENS Extended Resolver interface
interface IExtendedResolver {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

/// @notice ERC-165 interface
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/// @title CCResolver - Controlled Accounts ENS Extended Resolver
/// @notice ENS resolver that returns verified controlled accounts based on associated account signatures
/// @dev Implements ENS Extended Resolver interface with full text, data, addr, and contenthash support
contract CCResolver is IExtendedResolver, IERC165 {
    using AssociatedAccountsLib for *;

    // ENS method selectors
    bytes4 public constant ADDR_SELECTOR = 0x3b3b57de;          // addr(bytes32)
    bytes4 public constant ADDR_COINTYPE_SELECTOR = 0xf1cb7e06; // addr(bytes32,uint256)
    bytes4 public constant CONTENTHASH_SELECTOR = 0xbc1c58d1;   // contenthash(bytes32)
    bytes4 public constant TEXT_SELECTOR = 0x59d1d43c;          // text(bytes32,string)
    bytes4 public constant DATA_SELECTOR = 0xd700ff33;          // data(bytes32,string)

    // Coin type constant
    uint256 public constant ETHEREUM_COIN_TYPE = 60;

    /// @notice Struct representing a set of controlled accounts
    struct ControlledAccounts {
        uint256 id;
        bytes parentAccount; // ERC-7930 format (the initiator/delegate)
        bytes[] childAccounts; // Array of ERC-7930 format accounts (the controlled accounts)
        uint256 registeredAt;
    }

    /// @notice Reference to the AssociationsStore contract
    AssociationsStore public immutable associationsStore;

    /// @notice Magic data value that must be in association record's data field
    bytes public constant CONTROLLED_ACCOUNT_DATA = bytes("ControlledAccount");

    /// @notice Global nonce for auto-assigning IDs
    uint256 public nextId;

    /// @notice Text record prefix (updatable)
    string public textRecordPrefix;

    /// @notice Contract owner (can update prefix)
    address public owner;

    /// @notice Mapping from controlled accounts ID to the struct
    mapping(uint256 => ControlledAccounts) public controlledAccountsRegistry;

    /// @notice Mapping to track if an ID exists
    mapping(uint256 => bool) public idExists;

    // ENS record storage
    mapping(uint256 coinType => bytes value) private addressRecords;
    bytes private contenthashRecord;
    mapping(string key => string value) private textRecords;
    mapping(string key => bytes data) private dataRecords;

    /// @notice Events
    event ControlledAccountsRegistered(
        uint256 indexed id,
        bytes parentAccount,
        bytes[] childAccounts,
        address registrar
    );
    event AddrChanged(address a);
    event AddressChanged(uint256 coinType, bytes newAddress);
    event ContenthashChanged(bytes hash);
    event TextChanged(string indexed key, string value);
    event DataChanged(string indexed key, bytes data);

    /// @notice Errors
    error IdNotFound();
    error NoChildAccounts();
    error InvalidAssociation(bytes32 associationId);
    error InvalidData(bytes32 associationId, bytes actualData);
    error WrongAccountRoles(bytes32 associationId);
    error OnlyOwner();

    /// @notice Modifier to restrict access to owner
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(address _associationsStore, string memory _textRecordPrefix) {
        associationsStore = AssociationsStore(_associationsStore);
        textRecordPrefix = _textRecordPrefix;
        owner = msg.sender;
    }

    /// @notice Register a new set of controlled accounts
    /// @dev Verification happens at query time, not registration time, for real-time accuracy
    /// @dev ID is auto-generated from a global nonce
    /// @param parentAccount The parent/delegate account in ERC-7930 format
    /// @param childAccounts Array of controlled child accounts in ERC-7930 format
    /// @return id The auto-generated ID for this controlled accounts set
    function registerControlledAccounts(
        bytes calldata parentAccount,
        bytes[] calldata childAccounts
    ) external returns (uint256 id) {
        if (childAccounts.length == 0) revert NoChildAccounts();

        // Auto-generate ID from global nonce
        id = nextId++;

        // Store the controlled accounts
        ControlledAccounts storage ca = controlledAccountsRegistry[id];
        ca.id = id;
        ca.parentAccount = parentAccount;
        ca.registeredAt = block.timestamp;
        
        // Manually copy the childAccounts array
        for (uint256 i = 0; i < childAccounts.length; i++) {
            ca.childAccounts.push(childAccounts[i]);
        }
        
        idExists[id] = true;

        emit ControlledAccountsRegistered(id, parentAccount, childAccounts, msg.sender);
        
        return id;
    }

    /// @notice ENS Extended Resolver resolve function
    /// @dev Decodes the data parameter and routes to appropriate handler
    /// @param name The ENS name (DNS-encoded) - unused, single-label resolver
    /// @param data The ABI-encoded function call
    /// @return The result bytes
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory) {
        bytes4 selector = bytes4(data[:4]);
        
        if (selector == ADDR_SELECTOR) {
            // addr(bytes32) - return ETH address
            bytes memory v = addressRecords[ETHEREUM_COIN_TYPE];
            if (v.length == 0) {
                return abi.encode(payable(address(0)));
            }
            return abi.encode(_bytesToAddress(v));
        } else if (selector == ADDR_COINTYPE_SELECTOR) {
            // addr(bytes32,uint256) - return multi-coin address
            (, uint256 coinType) = abi.decode(data[4:], (bytes32, uint256));
            bytes memory a = addressRecords[coinType];
            return abi.encode(a);
        } else if (selector == CONTENTHASH_SELECTOR) {
            // contenthash(bytes32) - return content hash
            return abi.encode(contenthashRecord);
        } else if (selector == TEXT_SELECTOR) {
            // text(bytes32,string) - return text value (handles both regular and controlled-accounts)
            (bytes32 node, string memory key) = abi.decode(data[4:], (bytes32, string));
            return abi.encode(_resolveText(node, key));
        } else if (selector == DATA_SELECTOR) {
            // data(bytes32,string) - return data value
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            bytes memory dataValue = dataRecords[key];
            return abi.encode(dataValue);
        }
        
        // Return empty bytes if no selector matches
        return abi.encode("");
    }

    /// @notice Update the text record prefix
    /// @dev Only callable by owner
    /// @param newPrefix The new prefix (e.g., "eth.ecs.controlled-accounts:")
    function setTextRecordPrefix(string calldata newPrefix) external onlyOwner {
        textRecordPrefix = newPrefix;
    }

    /// @notice Transfer ownership
    /// @dev Only callable by current owner
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    /// @notice Internal text record resolver
    /// @dev Resolves text records - handles both regular text records and controlled-accounts prefix
    /// @param node The ENS node (namehash)
    /// @param key The text record key
    /// @return The text value or YAML-formatted ControlledAccounts struct if valid
    function _resolveText(bytes32 node, string memory key) internal view returns (string memory) {
        bytes memory keyBytes = bytes(key);
        bytes memory prefix = bytes(textRecordPrefix);
        
        // Check if this is a controlled-accounts query
        if (keyBytes.length > prefix.length) {
            bool isControlledAccountsKey = true;
            for (uint256 i = 0; i < prefix.length; i++) {
                if (keyBytes[i] != prefix[i]) {
                    isControlledAccountsKey = false;
                    break;
                }
            }
            
            if (isControlledAccountsKey) {
                // Extract ID from the key (parse string number to uint256)
                uint256 id = _parseIdFromString(keyBytes, prefix.length);
                
                if (!idExists[id]) {
                    return "";
                }

                ControlledAccounts storage ca = controlledAccountsRegistry[id];

                // Verify all associations in real-time
                try this._verifyAllAssociations(ca.parentAccount, ca.childAccounts) {
                    // All associations verified, return YAML-formatted struct
                    return _formatAsYAML(ca);
                } catch {
                    // Verification failed, return empty
                    return "";
                }
            }
        }
        
        // Not a controlled-accounts key, return regular text record
        return textRecords[key];
    }

    /// @notice Format ControlledAccounts as YAML
    /// @param ca The ControlledAccounts struct to format
    /// @return YAML-formatted string
    function _formatAsYAML(ControlledAccounts storage ca) internal view returns (string memory) {
        string memory yaml = string(abi.encodePacked(
            "id: ", Strings.toString(ca.id), "\n",
            "registeredAt: ", Strings.toString(ca.registeredAt), "\n",
            "parent: \"0x", _bytesToHexString(ca.parentAccount), "\"\n",
            "children:\n"
        ));
        
        for (uint256 i = 0; i < ca.childAccounts.length; i++) {
            yaml = string(abi.encodePacked(
                yaml,
                "  - \"0x", _bytesToHexString(ca.childAccounts[i]), "\"\n"
            ));
        }
        
        return yaml;
    }


    /// @notice Convert bytes to hex string (without 0x prefix)
    /// @param data The bytes to convert
    /// @return Hex string without 0x prefix
    function _bytesToHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(data.length * 2);
        
        for (uint256 i = 0; i < data.length; i++) {
            result[i * 2] = hexChars[uint8(data[i] >> 4)];
            result[i * 2 + 1] = hexChars[uint8(data[i] & 0x0f)];
        }
        
        return string(result);
    }

    /// @notice Direct text record query (for convenience/backwards compatibility)
    /// @dev Resolves text records in format: "controlled-accounts:<id>"
    /// @param node The ENS node (namehash)
    /// @param key The text record key
    /// @return The ABI-encoded ControlledAccounts struct if valid, empty string otherwise
    function text(bytes32 node, string calldata key) external view returns (string memory) {
        return _resolveText(node, key);
    }

    /// @notice Verify all associations between parent and children (external wrapper for try/catch)
    /// @param parentAccount The parent account
    /// @param childAccounts Array of child accounts
    function _verifyAllAssociations(
        bytes calldata parentAccount,
        bytes[] calldata childAccounts
    ) external view {
        _verifyAllAssociationsInternal(parentAccount, childAccounts);
    }

    /// @notice Verify all associations between parent and children (internal)
    /// @param parentAccount The parent account
    /// @param childAccounts Array of child accounts
    function _verifyAllAssociationsInternal(
        bytes calldata parentAccount,
        bytes[] calldata childAccounts
    ) internal view {
        for (uint256 i = 0; i < childAccounts.length; i++) {
            _verifySingleAssociation(parentAccount, childAccounts[i]);
        }
    }

    /// @notice Verify a single association between parent and child
    /// @param parentAccount The parent/initiator account
    /// @param childAccount The child/approver account
    function _verifySingleAssociation(
        bytes calldata parentAccount,
        bytes calldata childAccount
    ) internal view {
        // Get the association between these two accounts
        (bool exists, AssociatedAccounts.SignedAssociationRecord memory sar) = 
            associationsStore.getAssociationBetweenAccounts(parentAccount, childAccount);

        if (!exists) {
            bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
            revert InvalidAssociation(associationId);
        }

        // Verify the initiator is the parent account and approver is the child
        bytes32 initiatorHash = keccak256(sar.record.initiator);
        bytes32 approverHash = keccak256(sar.record.approver);
        bytes32 parentHash = keccak256(parentAccount);
        bytes32 childHash = keccak256(childAccount);

        if (initiatorHash != parentHash || approverHash != childHash) {
            bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
            revert WrongAccountRoles(associationId);
        }

        // Verify the data field contains "ControlledAccount"
        if (keccak256(sar.record.data) != keccak256(CONTROLLED_ACCOUNT_DATA)) {
            bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
            revert InvalidData(associationId, sar.record.data);
        }

        // Validate the association signatures and timestamps using the library
        if (!sar.validateAssociatedAccount()) {
            bytes32 associationId = AssociatedAccountsLib.associationIdFromSAR(sar);
            revert InvalidAssociation(associationId);
        }
    }

    /// @notice Parse uint256 ID from string (e.g., "123" -> 123)
    /// @param keyBytes The full key as bytes
    /// @param startIndex Where to start parsing the number
    /// @return The parsed uint256 ID
    function _parseIdFromString(bytes memory keyBytes, uint256 startIndex) internal pure returns (uint256) {
        uint256 result = 0;
        
        for (uint256 i = startIndex; i < keyBytes.length; i++) {
            uint8 digit = uint8(keyBytes[i]);
            
            // Check if it's a digit (0-9)
            if (digit >= 48 && digit <= 57) {
                result = result * 10 + (digit - 48);
            } else {
                // Stop parsing on non-digit character
                break;
            }
        }
        
        return result;
    }

    /// @notice Get controlled accounts by ID (convenience function)
    /// @param id The controlled accounts ID
    /// @return The ControlledAccounts struct
    function getControlledAccounts(uint256 id) external view returns (ControlledAccounts memory) {
        if (!idExists[id]) revert IdNotFound();
        return controlledAccountsRegistry[id];
    }

    /// @notice Check if controlled accounts are currently valid
    /// @param id The controlled accounts ID
    /// @return True if all associations are valid, false otherwise
    function isValid(uint256 id) external view returns (bool) {
        if (!idExists[id]) return false;
        
        ControlledAccounts storage ca = controlledAccountsRegistry[id];
        
        try this._verifyAllAssociations(ca.parentAccount, ca.childAccounts) {
            return true;
        } catch {
            return false;
        }
    }

    // ============ ENS Resolver Setter Functions (Owner Only) ============

    /// @notice Set the ETH address (coin type 60)
    /// @param _addr The EVM address to set
    function setAddr(address _addr) external onlyOwner {
        addressRecords[ETHEREUM_COIN_TYPE] = abi.encodePacked(_addr);
        emit AddrChanged(_addr);
    }

    /// @notice Set a multi-coin address for a given coin type
    /// @param _coinType The coin type (per ENSIP-11)
    /// @param _value The raw address bytes encoded for that coin type
    function setAddr(uint256 _coinType, bytes calldata _value) external onlyOwner {
        addressRecords[_coinType] = _value;
        emit AddressChanged(_coinType, _value);
        if (_coinType == ETHEREUM_COIN_TYPE) {
            emit AddrChanged(_bytesToAddress(_value));
        }
    }

    /// @notice Set the content hash
    /// @param _hash The content hash to set
    function setContenthash(bytes calldata _hash) external onlyOwner {
        contenthashRecord = _hash;
        emit ContenthashChanged(_hash);
    }

    /// @notice Set a text record
    /// @param _key The text record key
    /// @param _value The text record value
    function setText(string calldata _key, string calldata _value) external onlyOwner {
        textRecords[_key] = _value;
        emit TextChanged(_key, _value);
    }

    /// @notice Set a data record
    /// @param _key The data record key
    /// @param _data The data record value
    function setData(string calldata _key, bytes calldata _data) external onlyOwner {
        dataRecords[_key] = _data;
        emit DataChanged(_key, _data);
    }

    // ============ ENS Resolver Getter Functions ============

    /// @notice Get the address with a specific coin type
    /// @param node The ENS node (unused, single-label resolver)
    /// @param _coinType The coin type (default: 60 for Ethereum)
    /// @return The address for this coin type
    function addr(bytes32 node, uint256 _coinType) external view returns (bytes memory) {
        return addressRecords[_coinType];
    }

    /// @notice Get the content hash
    /// @param node The ENS node (unused, single-label resolver)
    /// @return The content hash
    function contenthash(bytes32 node) external view returns (bytes memory) {
        return contenthashRecord;
    }

    /// @notice Get a data record
    /// @param node The ENS node (unused, single-label resolver)
    /// @param _key The data record key
    /// @return The data record value
    function data(bytes32 node, string calldata _key) external view returns (bytes memory) {
        return dataRecords[_key];
    }

    // ============ ERC-165 Support ============

    /// @notice Check if this contract supports a given interface
    /// @param interfaceId The interface identifier
    /// @return True if the interface is supported
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || 
               interfaceId == type(IExtendedResolver).interfaceId;
    }

    // ============ Helper Functions ============

    /// @notice Decodes a packed 20-byte value into an EVM address
    /// @param b The 20-byte sequence
    /// @return a The decoded payable address
    function _bytesToAddress(bytes memory b) internal pure returns (address payable a) {
        require(b.length == 20, "Invalid address length");
        assembly {
            a := div(mload(add(b, 32)), exp(256, 12))
        }
    }
}

