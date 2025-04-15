// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library Environment {
    address internal constant APP_CHAIN_NATIVE_TOKEN = 0x0000000000000000000000000000000000000000;

    /* ============ Factory ============ */

    string internal constant FACTORY_OUTPUT_JSON = "Factory";

    address internal constant FACTORY = 0x0000000000000000000000000000000000000000;

    /* ============ Parameter Registry ============ */

    string internal constant SETTLEMENT_CHAIN_PARAMETER_REGISTRY_OUTPUT_JSON = "SettlementChainParameterRegistry";

    address internal constant SETTLEMENT_CHAIN_PARAMETER_REGISTRY_IMPLEMENTATION =
        0x0000000000000000000000000000000000000000;

    string internal constant APP_CHAIN_PARAMETER_REGISTRY_OUTPUT_JSON = "AppChainParameterRegistry";

    address internal constant APP_CHAIN_PARAMETER_REGISTRY_IMPLEMENTATION = 0x0000000000000000000000000000000000000000;

    // NOTE: Use the same salt for both the settlement and app chain parameter registry proxies to ensure they have the
    //       same address. While this is not required by the code, the symmetry is desirable.
    bytes32 internal constant PARAMETER_REGISTRY_PROXY_SALT = "ParameterRegistry_0";

    // NOTE: Since the salt used to deploy the settlement and app chain parameter registry proxies is the same, the
    //       expected address of both parameter registry proxies is the same.
    address internal constant PARAMETER_REGISTRY_PROXY = 0x0000000000000000000000000000000000000000;

    address internal constant SETTLEMENT_CHAIN_PARAMETER_REGISTRY_ADMIN_1 = 0x0000000000000000000000000000000000000000;
    address internal constant SETTLEMENT_CHAIN_PARAMETER_REGISTRY_ADMIN_2 = 0x0000000000000000000000000000000000000000;
    address internal constant SETTLEMENT_CHAIN_PARAMETER_REGISTRY_ADMIN_3 = 0x0000000000000000000000000000000000000000;

    /* ============ Gateway ============ */

    string internal constant SETTLEMENT_CHAIN_GATEWAY_OUTPUT_JSON = "SettlementChainGateway";

    address internal constant SETTLEMENT_CHAIN_GATEWAY_IMPLEMENTATION = 0x0000000000000000000000000000000000000000;

    string internal constant APP_CHAIN_GATEWAY_OUTPUT_JSON = "AppChainGateway";

    address internal constant APP_CHAIN_GATEWAY_IMPLEMENTATION = 0x0000000000000000000000000000000000000000;

    // NOTE: Use the same salt for both the settlement and app chain gateway proxies to ensure they have the same
    //       address. While this is not required by the code, the symmetry is desirable.
    bytes32 internal constant GATEWAY_PROXY_SALT = "Gateway_0";

    // NOTE: Since the salt used to deploy the settlement and app chain gateway proxies is the same, the expected
    //       address of both gateway proxies is the same.
    address internal constant GATEWAY_PROXY = 0x0000000000000000000000000000000000000000;

    /* ============ Group Message Broadcaster ============ */

    string internal constant GROUP_MESSAGE_BROADCASTER_OUTPUT_JSON = "GroupMessageBroadcaster";

    address internal constant GROUP_MESSAGE_BROADCASTER_IMPLEMENTATION = 0x0000000000000000000000000000000000000000;

    bytes32 internal constant GROUP_MESSAGE_BROADCASTER_PROXY_SALT = "GroupMessageBroadcaster_0";

    address internal constant GROUP_MESSAGE_BROADCASTER_PROXY = 0x0000000000000000000000000000000000000000;

    /* ============ Identity Update Broadcaster ============ */

    string internal constant IDENTITY_UPDATE_BROADCASTER_OUTPUT_JSON = "IdentityUpdateBroadcaster";

    address internal constant IDENTITY_UPDATE_BROADCASTER_IMPLEMENTATION = 0x0000000000000000000000000000000000000000;

    bytes32 internal constant IDENTITY_UPDATE_BROADCASTER_PROXY_SALT = "IdentityUpdateBroadcaster_0";

    address internal constant IDENTITY_UPDATE_BROADCASTER_PROXY = 0x0000000000000000000000000000000000000000;

    /* ============ Node Registry ============ */

    string internal constant NODE_REGISTRY_OUTPUT_JSON = "NodeRegistry";

    address internal constant NODE_REGISTRY_ADMIN = 0x0000000000000000000000000000000000000000;

    address internal constant NODE_REGISTRY_IMPLEMENTATION = 0x0000000000000000000000000000000000000000;

    /* ============ Rate Registry ============ */

    string internal constant RATE_REGISTRY_OUTPUT_JSON = "RateRegistry";

    address internal constant RATE_REGISTRY_IMPLEMENTATION = 0x0000000000000000000000000000000000000000;

    bytes32 internal constant RATE_REGISTRY_SALT = "RateRegistry_0";

    address internal constant RATE_REGISTRY_ADMIN = 0x0000000000000000000000000000000000000000;

    address internal constant RATE_REGISTRY_PROXY = 0x0000000000000000000000000000000000000000;
}
