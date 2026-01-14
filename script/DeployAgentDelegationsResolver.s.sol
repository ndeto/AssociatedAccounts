// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {AgentDelegationsResolver} from "../src/AgentDelegationsResolver.sol";

/**
 * @notice Deploy the AgentDelegationsResolver with a given AssociationsStore and text record prefix.
 */
contract DeployAgentDelegationsResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address associationsStore = vm.envAddress("BASE_SEPOLIA_ASSOCIATIONS_STORE_ADDRESS");
        string memory textRecordPrefix =
            vm.envOr("TEXT_RECORD_PREFIX", string("eth.ecs.agent-delegations:"));

        vm.startBroadcast(deployerPrivateKey);
        AgentDelegationsResolver resolver = new AgentDelegationsResolver(associationsStore, textRecordPrefix);
        vm.stopBroadcast();

        console2.log("AgentDelegationsResolver deployed at:", address(resolver));
        console2.log("AssociationsStore:", associationsStore);
        console2.log("Text record prefix:", textRecordPrefix);
        console2.log("Chain ID:", block.chainid);
    }
}
