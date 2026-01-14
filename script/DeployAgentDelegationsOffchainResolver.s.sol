// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {AgentDelegationsOffchainResolver} from "../src/AgentDelegationsOffchainResolver.sol";

/**
 * @notice Deploy the offchain resolver that emits ERC-3668 OffchainLookup.
 */
contract DeployAgentDelegationsOffchainResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        string memory url = vm.envString("AGENT_DELEGATIONS_GATEWAY_URL");

        vm.startBroadcast(deployerPrivateKey);
        AgentDelegationsOffchainResolver resolver = new AgentDelegationsOffchainResolver(url);
        vm.stopBroadcast();

        console2.log("AgentDelegationsOffchainResolver deployed at:", address(resolver));
        console2.log("Gateway URL:", url);
    }
}
