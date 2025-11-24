//------------------------------------------------------------------------------
// PROCESS STEPS FOR UPGRADES
//------------------------------------------------------------------------------
// STEP 1) Setup
1) in .env file ensure these are set:
  ADMIN_PRIVATE_KEY
  BASE_SEPOLIA_RPC_URL
  ETHERSCAN_API_KEY
  ETHERSCAN_API_URL

2) in config/<env>.json file, ensure these are correct:
  factory                        (used for upgrades)
  parameterRegistryProxy         (used to set migrator address)
  <contract-being-upgraded>Proxy (this is what is upgraded)

  Upgrades dont care what the new address is for a new implementation (different from deploys that currently require we predict it correctly)
  There are no dependencies on environment/<env>.json.

// STEP 2) Process per contract:
1) execute line below - this does end to end upgrade (deploy impl or no-op, deploy migrator, set parameter, execute upgrade)
2) manually copy newImpl field value to the config/testnet-dev.json file
3) code verification only needed once per impl 

// testnet-dev, singletons marked with [1] as start:
    ENVIRONMENT=testnet-dev forge script script/upgrades/NodeRegistryUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeNodeRegistry()" --broadcast
    ENVIRONMENT=testnet-dev forge script script/upgrades/PayerRegistryUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradePayerRegistry()" --broadcast
[1] ENVIRONMENT=testnet-dev forge script script/upgrades/FeeTokenUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeFeeToken()" --broadcast
[1] ENVIRONMENT=testnet-dev forge script script/upgrades/SettlementChainParameterRegistryUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeSettlementChainParameterRegistry()" --broadcast
[1] ENVIRONMENT=testnet-dev forge script script/upgrades/SettlementChainGatewayUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeSettlementChainGateway()" --broadcast
    ENVIRONMENT=testnet-dev forge script script/upgrades/PayerReportManagerUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradePayerReportManager()" --broadcast
    ENVIRONMENT=testnet-dev forge script script/upgrades/RateRegistryUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeRateRegistry()" --broadcast
    ENVIRONMENT=testnet-dev forge script script/upgrades/DistributionManagerUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeDistributionManager()" --broadcast

forge verify-contract --chain-id 84532 0xbADD84C576c1426F94e7be2f0a092243D0a10580 src/settlement-chain/NodeRegistry.sol:NodeRegistry
forge verify-contract --chain-id 84532 0xffF6fD963B3d7F15d917D446c0c1C237292AD3E0 src/settlement-chain/PayerRegistry.sol:PayerRegistry
forge verify-contract --chain-id 84532 0x6D07cbAF4C4991A00Ab1A4528666190Cd3385285 src/settlement-chain/FeeToken.sol:FeeToken
forge verify-contract --chain-id 84532 0xA860f449b6e90D72b6958036D5123219fE6b2c59 src/settlement-chain/SettlementChainParameterRegistry.sol:SettlementChainParameterRegistry
forge verify-contract --chain-id 84532 0x6748bfc9ce3bbF672E93A5beD18043B73600072B src/settlement-chain/SettlementChainGateway.sol:SettlementChainGateway
forge verify-contract --chain-id 84532 0xBE241D106B0EC495fFFc5E42535265fD3E50548d src/settlement-chain/PayerReportManager.sol:PayerReportManager
forge verify-contract --chain-id 84532 0xBa0479d260e3276142Ba338dfC5498407e1d4063 src/settlement-chain/RateRegistry.sol:RateRegistry
forge verify-contract --chain-id 84532 0x78bEfb0130dA6038e9a3C5a000fC4cbBb7ee8a42 src/settlement-chain/DistributionManager.sol:DistributionManager

// testnet-staging, singletons removed:
// None of these 3 are executed yet:
  ENVIRONMENT=testnet-staging forge script script/upgrades/NodeRegistryUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeNodeRegistry()" --broadcast
  ENVIRONMENT=testnet-staging forge script script/upgrades/PayerRegistryUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradePayerRegistry()" --broadcast
  // NOT NEEDED REDEPLOYED ENVIRONMENT=testnet-staging forge script script/upgrades/PayerReportManagerUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradePayerReportManager()" --broadcast
  ENVIRONMENT=testnet-staging forge script script/upgrades/RateRegistryUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeRateRegistry()" --broadcast
  // NOT NEEDED REDEPLOYED ENVIRONMENT=testnet-staging forge script script/upgrades/DistributionManagerUpgrader.s.sol --rpc-url base_sepolia --sig "UpgradeDistributionManager()" --broadcast

