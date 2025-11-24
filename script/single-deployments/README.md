# Process Steps for Single Deployments

A **single deployment** refers to deploying a new **proxy and implementation pair** for a given contract. Any dependencies must be manually maintained. All examples below use the environment of `staging`, so config files are named `testnet-staging.json`.

## Deploy New Payer Report Manager
When there is a new Payer Report Manager address, the following dependencies need updated:
- 
- 
- 

The instructions cover the conplete process of deploying a new Payer Report Manager and updating all dependencies.

### Deploy New Payer Report Manager
1. Maintain the root `.env` file to have:
- [ ] `DEPLOYER` address and `DEPLOYER_PRIVATE_KEY`. This can be any address with gas tokens.
- [ ] `ADMIN` and `ADMIN_PRIVATE_KEY`. This address must be an admin of the `SettlementChainParameterRegistry`. This address is used during a deploy to point the proxy at the new implementation.
- [ ] `BASE_SEPOLIA_RPC_URL` your RPC provider.
- [ ] `ETHERSCAN_API_KEY` your etherscan API key.
- [ ] `ETHERSCAN_API_URL` 'https://api-sepolia.basescan.org/api'

2. Edit file `config/testnet-staging.json` to have:
- [ ] The above deployer address.
- [ ] Adjust the `payerReportManagerProxySalt` to be something new. For example, use `*_0_x` for `dev`, use `*_1_x` for staging. The deterministic proxy address depends on the **deployer address** maintained above + this **proxy salt**.
    
3. Run predicted address helper:
- [ ] Run this to calculate what new addresses will be, and copy the predicted values for proxy and implementation. This call will show warnings if the proxy or implementation is already in use. If the proxy is already in use, you can change the salt in previous step:
```
ENVIRONMENT=testnet-staging forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "predictAddresses()"
```

4. Maintain `config/testnet-staging.json` to have:
- [ ] Predicted implementation address from previous step
- [ ] Predicted proxy address from previous step

5. Maintain `environments/testnet-staging.json` to have:
- [ ] Deployer address from earlier step.
- [ ] Delete the existing row for `payerReportManager`. This will be replaced when we deploy the new proxy.

6. Deployment  
This will update the `environments/testnet-staging.json` file with the newly deployed proxy.
```
ENVIRONMENT=testnet-staging forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
```

7. Post deploy dependencies
These should only run AFTER deploy happened and environments json updated, or manually add to environments json
ENVIRONMENT=testnet-staging forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "updateDependencies()"
x then --broadcast

//------------------------------------------------------------------------------
// STAGE 2 - DEPLOY NEW DISTRIBUTION MANAGER
//------------------------------------------------------------------------------
edit config/*.json to have:
x adjust the distribution manager proxy salt to be something new  

run predicted address helper  
x ENVIRONMENT=testnet-staging forge script DeployDistributionManagerScript --rpc-url base_sepolia --slow --sig "predictAddresses()"

check salt does indeed give a new address
x look on-chain at predicted proxy address, does it have code? if it does you need to change proxy salt
  
edit config/*.json to have:
x correct predicted implementation
x correct predicted proxy

edit environments/*.json to have:
x remove proxy row

// Dry run deployment  
ENVIRONMENT=testnet-staging forge script DeployDistributionManagerScript --rpc-url base_sepolia --slow --sig "deployContract()"
x then --broadcast

// Post deploy dependencies - these should only run AFTER deploy happened and environments json updated, or manually add to environments json
ENVIRONMENT=testnet-staging forge script DeployDistributionManagerScript --rpc-url base_sepolia --slow --sig "updateDependencies()"
then --broadcast

//------------------------------------------------------------------------------
code verification already done
put json changes in a n PR



// SUPPLEMENTAL
// Code Verification  
forge verify-contract --chain-id 84532 0x380133f8d827A370add3CD56eacA95dd9Ff84ff5 src/settlement-chain/NodeRegistry.sol:NodeRegistry
forge verify-contract --chain-id 84532 0x6Dce63E91B5833BFb5E3C30d7EF7435E8c13F876 src/settlement-chain/PayerReportManager.sol:PayerReportManager
forge verify-contract --chain-id 84532 0xffF6fD963B3d7F15d917D446c0c1C237292AD3E0 src/settlement-chain/PayerRegistry.sol:PayerRegistry
forge verify-contract --chain-id 84532 0xed1776e60C3ea3FEA6468a1d45cdf82577A7D1Af src/settlement-chain/DistributionManager.sol:DistributionManager


// It is idempotent, will report "Warning: No transactions to broadcast." if nothing to do  
sample log with broadcast
  Environment: testnet-dev
  Deployer: 0xE4b610ac9E75F98eaa1CC83eC1ac6A9eCaEe1e9f
  Deploying PayerReportManager
  PayerReportManager Implementation Name: PayerReportManager
  PayerReportManager Implementation Version: 1.0.0
  PayerReportManager Implementation: 0x6Dce63E91B5833BFb5E3C30d7EF7435E8c13F876
  PayerReportManager Proxy Salt: PayerReportManager_0_1
  PayerReportManager Proxy: 0xB19d5B4D8BdADE557f36c49b973789C24Ba19893
  PayerReportManager deployment complete

