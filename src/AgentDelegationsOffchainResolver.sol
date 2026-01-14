// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title AgentDelegationsOffchainResolver
/// @notice Minimal ENS-compatible resolver that proxies Agent Delegations lookups to an HTTP gateway via CCIP-Read.
/// @dev The resolver only emits OffchainLookup; the gateway is expected to fetch the association payload.
contract AgentDelegationsOffchainResolver {
    /// @dev CCIP-Read error as specified by ERC-3668.
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    string public url;
    address private owner;

    enum RequestKind {
        Text,
        Data
    }

    constructor(string memory _url) {
        url = _url;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @notice Update the gateway URL (demo-only mutability).
    function setUrl(string calldata newUrl) external onlyOwner {
        url = newUrl;
    }

    /// @notice ENS text() implementation that always triggers CCIP-Read.
    function text(bytes32 node, string calldata key) external view returns (string memory) {
        _revertOffchainLookup(RequestKind.Text, node, key);
    }

    /// @notice ENS data() implementation that always triggers CCIP-Read.
    function data(bytes32 node, string calldata key) external view returns (bytes memory) {
        _revertOffchainLookup(RequestKind.Data, node, key);
    }

    function textWithProof(bytes calldata response, bytes calldata) external pure returns (string memory) {
        return abi.decode(response, (string));
    }

    function dataWithProof(bytes calldata response, bytes calldata) external pure returns (bytes memory) {
        return abi.decode(response, (bytes));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x59d1d43c // text(bytes32,string)
            || interfaceId == 0xd700ff33 // data(bytes32,string)
            || interfaceId == this.supportsInterface.selector;
    }

    function _revertOffchainLookup(RequestKind kind, bytes32 node, string calldata key) internal view {
        string[] memory urls = new string[](1);
        urls[0] = url;

        bytes memory callData = abi.encode(kind, node, key);
        bytes memory extraData = abi.encode(kind, node, key);
        bytes4 callback = kind == RequestKind.Text ? this.textWithProof.selector : this.dataWithProof.selector;

        revert OffchainLookup(address(this), urls, callData, callback, extraData);
    }
}
