// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";

interface IECSRegistrar {
    function createCommitment(
        string memory label,
        address owner,
        address resolver,
        uint256 duration,
        bytes32 secret
    ) external pure returns (bytes32);

    function commit(bytes32 commitment) external;
}

/**
 * @notice Commit a label update via the ECS registrar
 */
contract CommitEcsLabel is Script {
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

        bytes32 commitment = IECSRegistrar(registrar).createCommitment(
            label,
            owner,
            resolver,
            durationSeconds,
            secret
        );

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        IECSRegistrar(registrar).commit(commitment);
        vm.stopBroadcast();

        console2.log("Registrar:", registrar);
        console2.log("Label:", label);
        console2.logBytes32(commitment);
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
