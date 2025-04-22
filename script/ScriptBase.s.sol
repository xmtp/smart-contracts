// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "../lib/forge-std/src/Script.sol";

import { Utils } from "./utils/Utils.sol";

contract ScriptBase is Script {
    error EnvironmentNotSet();
    error PrivateKeyNotSet();
    error DeployerNotSet();
    error UnexpectedDeployer();

    Utils.DeploymentData internal _deploymentData;

    uint256 internal _privateKey;
    address internal _deployer;

    function setUp() public virtual {
        string memory environment_ = vm.envString("ENVIRONMENT");

        require(bytes(environment_).length != 0, EnvironmentNotSet());

        _deploymentData = Utils.parseDeploymentData(string.concat("config/", environment_, ".json"));

        require(_deploymentData.deployer != address(0), DeployerNotSet());

        _privateKey = vm.envUint("PRIVATE_KEY");

        require(_privateKey != 0, PrivateKeyNotSet());

        _deployer = vm.addr(_privateKey);

        require(_deployer == _deploymentData.deployer, UnexpectedDeployer());
    }
}
