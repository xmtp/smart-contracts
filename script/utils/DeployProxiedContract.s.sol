// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { CREATE3Factory } from "../../src/CREATE3Factory.sol";
import { ERC1967Proxy } from "../../lib/oz/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Utils } from "./Utils.sol";
import { Environment } from "./Environment.sol";

/**
 * @title DeployProxiedContract
 * @notice Base abstract contract for deploying proxied contracts using a CREATE3 factory.
 */
abstract contract DeployProxiedContract is Utils, Environment {
    uint256 private _privateKey;

    CREATE3Factory public factory;

    bytes32 public implementationSalt;
    bytes32 public proxySalt;

    address public admin;
    address public deployer;
    address public implementation;
    address public proxy;

    /// @dev Abstract functions that child scripts must implement.
    function _getImplementationCreationCode() internal pure virtual returns (bytes memory);
    function _getAdminEnvVar() internal pure virtual returns (string memory);
    function _getOutputFilePath() internal view virtual returns (string memory);
    function _getProxySalt() internal pure virtual returns (bytes32);
    function _getImplementationSalt() internal pure virtual returns (bytes32);
    function _getInitializeCalldata() internal view virtual returns (bytes memory);

    /// @dev This is the main function that forge script will call.
    function run() external {
        _setup();

        vm.startBroadcast(_privateKey);

        address implPredictedAddress = factory.predictDeterministicAddress(implementationSalt, deployer);
        require(implPredictedAddress != address(0), "Implementation predicted address is zero");
        require(implPredictedAddress.code.length == 0, "Implementation predicted address has code");

        address proxyPredictedAddress = factory.predictDeterministicAddress(proxySalt, deployer);
        require(proxyPredictedAddress != address(0), "Proxy predicted address is zero");
        require(proxyPredictedAddress.code.length == 0, "Proxy predicted address has code");

        implementation = factory.deploy(implementationSalt, _getImplementationCreationCode());
        require(
            implPredictedAddress == implementation,
            "Implementation deployed address doesn't match predicted address"
        );

        bytes memory proxyInitCode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, _getInitializeCalldata())
        );

        proxy = factory.deploy(proxySalt, proxyInitCode);
        require(proxyPredictedAddress == proxy, "Proxy deployed address doesn't match predicted address");

        vm.stopBroadcast();

        _serializeDeploymentData();
    }

    function _setup() internal {
        implementationSalt = _getImplementationSalt();
        proxySalt = _getProxySalt();

        admin = vm.envAddress(_getAdminEnvVar());
        require(admin != address(0), string(abi.encodePacked(_getAdminEnvVar(), " not set")));

        address create3Factory = vm.envAddress("XMTP_CREATE3_FACTORY_ADDRESS");
        require(create3Factory != address(0), "XMTP_CREATE3_FACTORY_ADDRESS not set");

        _privateKey = vm.envUint("PRIVATE_KEY");
        require(_privateKey != 0, "PRIVATE_KEY not set");

        deployer = vm.addr(_privateKey);
        factory = CREATE3Factory(create3Factory);
    }

    /// @dev This function can be overriden if the child contract needs to serialize different data.
    function _serializeDeploymentData() internal virtual {
        string memory parent_object = "parent object";
        string memory addresses = "addresses";

        string memory addressesOutput;

        addressesOutput = vm.serializeAddress(addresses, "deployer", deployer);
        addressesOutput = vm.serializeAddress(addresses, "proxyAdmin", admin);
        addressesOutput = vm.serializeAddress(addresses, "proxy", address(proxy));
        addressesOutput = vm.serializeAddress(addresses, "implementation", address(implementation));

        string memory finalJson;
        finalJson = vm.serializeString(parent_object, addresses, addressesOutput);
        finalJson = vm.serializeUint(parent_object, "deploymentBlock", block.number);
        finalJson = vm.serializeUint(parent_object, "latestUpgradeBlock", block.number);

        writeOutput(finalJson, _getOutputFilePath());
    }
}
