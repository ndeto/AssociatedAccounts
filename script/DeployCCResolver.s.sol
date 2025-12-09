// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {CCResolver} from "../src/CCResolver.sol";
import {AssociationsStore} from "../src/AssociationsStore.sol";

/// @notice Deployment script for CCResolver
/// @dev Run with: forge script script/DeployCCResolver.s.sol:DeployCCResolverScript --rpc-url <RPC_URL> --broadcast
contract DeployCCResolverScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Check if AssociationsStore address is provided
        address associationsStoreAddress = vm.envOr("ASSOCIATIONS_STORE_ADDRESS", address(0));
        
        AssociationsStore store;
        if (associationsStoreAddress == address(0)) {
            // Deploy AssociationsStore if not provided
            console2.log("Deploying new AssociationsStore...");
            store = new AssociationsStore();
            console2.log("AssociationsStore deployed at:", address(store));
        } else {
            // Use existing AssociationsStore
            console2.log("Using existing AssociationsStore at:", associationsStoreAddress);
            store = AssociationsStore(associationsStoreAddress);
        }

        // Deploy CCResolver with initial prefix
        string memory initialPrefix = "eth.ecs.controlled-accounts:";
        console2.log("Deploying CCResolver...");
        console2.log("Initial prefix:", initialPrefix);
        CCResolver resolver = new CCResolver(address(store), initialPrefix);
        console2.log("CCResolver deployed at:", address(resolver));

        vm.stopBroadcast();

        // Log deployment info
        console2.log("\n=== Deployment Summary ===");
        console2.log("AssociationsStore:", address(store));
        console2.log("CCResolver:", address(resolver));
        console2.log("Chain ID:", block.chainid);
        console2.log("=========================\n");
    }
}

