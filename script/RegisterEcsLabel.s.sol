// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";

interface IECSRegistrar {
    function rentPrice(
        string memory label,
        uint256 duration
    ) external view returns (uint256);

    function register(
        string calldata label,
        address owner,
        address resolver,
        uint256 duration,
        bytes32 secret
    ) external payable;
}

/**
 * @notice Register a label via the ECS registrar after commitment.
 */
contract RegisterEcsLabel is Script {
    function run() public {
        address registrar = vm.envAddress("ECS_REGISTRAR_ADDRESS");
        string memory label = vm.envString("ECS_LABEL");
        address owner = vm.envAddress("LABEL_OWNER");
        address resolver = vm.envAddress(
            "BASE_SEPOLIA_AGENT_DELEGATIONS_RESOLVER_ADDRESS"
        );
        bytes32 secret = vm.envBytes32("COMMITMENT_SECRET");

        uint256 durationSeconds = _envUintOr(
            "ECS_LABEL_DURATION_SECONDS",
            365 days
        );
        uint256 price = IECSRegistrar(registrar).rentPrice(
            label,
            durationSeconds
        );

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IECSRegistrar(registrar).register{value: price}(
            label,
            owner,
            resolver,
            durationSeconds,
            secret
        );
        vm.stopBroadcast();

        console2.log("Registrar:", registrar);
        console2.log("Label:", label);
        console2.log("Owner:", owner);
        console2.log("Resolver:", resolver);
        console2.log("Duration:", durationSeconds);
        console2.log("Price:", price);
    }

    function _envUintOr(
        string memory key,
        uint256 fallbackValue
    ) internal view returns (uint256) {
        try vm.envUint(key) returns (uint256 value) {
            return value;
        } catch {
            return fallbackValue;
        }
    }
}
