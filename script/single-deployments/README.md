# Process Steps for Single Deployments

A **single deployment** refers to deploying a new **proxy and implementation pair** for a given contract. Any dependencies must be manually maintained. All examples below use the environment of `staging`, so config files are named `testnet-staging.json`.


## STAGE 1 - Deploy New Payer Report Manager
When there is a new Payer Report Manager address, the following dependencies need to be updated:
- The `PayerRegistry` has a field `settler` that contains the payer report manager. This is handled below by the `DeployPayerReportManagerScript.updateDependencies()` call.
- The `DistributionManager` has an immutable field, set at constructor time, containing the payer report manager address. Therefore `DistributionManager` needs to be redeployed.

The instructions below cover the complete process of deploying a new Payer Report Manager and updating all dependencies, including deploying a new `DistributionManager` and updating *its* dependencies.

### 1. Maintain the root `.env` file to have:
- [ ] `DEPLOYER` address and `DEPLOYER_PRIVATE_KEY`. This can be any address with gas tokens.
- [ ] `ADMIN` and `ADMIN_PRIVATE_KEY`. This address must be an admin of the `SettlementChainParameterRegistry`. This address is used during a deploy to point the proxy at the new implementation.
- [ ] `BASE_SEPOLIA_RPC_URL` your RPC provider.
- [ ] `ETHERSCAN_API_KEY` your etherscan API key.
- [ ] `ETHERSCAN_API_URL` 'https://api-sepolia.basescan.org/api'

### 2. Edit file `config/testnet-staging.json` to have:
- [ ] The above deployer address.
- [ ] Adjust the `payerReportManagerProxySalt` to be something new. For example, use `*_0_x` for `dev`, use `*_1_x` for staging. The deterministic proxy address depends on the **deployer address** maintained above + this **proxy salt**.
    
### 3. Run predicted address helper:
- [ ] Run this to calculate what new addresses will be, and copy the predicted values for proxy and implementation. This call will show warnings if the proxy or implementation is already in use. If the proxy is already in use, you can change the salt in previous step:
```
ENVIRONMENT=testnet-staging forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "predictAddresses()"
```

### 4. Maintain `config/testnet-staging.json` to have:
- [ ] Predicted implementation address from previous step
- [ ] Predicted proxy address from previous step

### 5. Maintain `environments/testnet-staging.json` to have:
- [ ] Deployer address from earlier step.
- [ ] Delete the existing row for `payerReportManager`. This will be replaced when we deploy the new proxy.

### 6. Deployment  
This will update the `environments/testnet-staging.json` file with the newly deployed proxy.
```
ENVIRONMENT=testnet-staging forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
```

### 7. Post deploy dependencies
Run this to update dependencies. This updates the SettlementChainParameterRegistry key `xmtp.payerRegistry.settler` with the new `PayerReportManager` proxy address. It then calls `PayerRegistry.updateSettler()` to update the settler in the `PayerRegistry` contract.
```
ENVIRONMENT=testnet-staging forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "updateDependencies()" --broadcast
```


## STAGE 2 - Deploy New Distribution Manager
Assuming that all values maintained in previous stage remain (the `.env` values in particular) then the following steps are required:

### 1. Edit file `config/testnet-staging.json`:
- [ ] Adjust the `DistributionManagerSalt` to be something new. 

### 2. Run predicted address helper:
- [ ] Run this to calculate what new addresses will be, and copy the predicted values for proxy and implementation:
```
ENVIRONMENT=testnet-staging forge script DeployDistributionManagerScript --rpc-url base_sepolia --slow --sig "predictAddresses()"
```

### 3. Maintain `config/testnet-staging.json` to have:
- [ ] Predicted implementation address from previous step
- [ ] Predicted proxy address from previous step

### 4. Maintain `environments/testnet-staging.json` to have:
- [ ] Delete the existing row for `distributionManager`. This will be replaced when we deploy the new proxy.

### 5. Deployment  
This will update the `environments/testnet-staging.json` file with the newly deployed proxy.
```
ENVIRONMENT=testnet-staging forge script DeployDistributionManagerScript --rpc-url base_sepolia --slow --sig "deployContract()" --broadcast
```

### 6. Post deploy dependencies
Run this to update dependencies. This updates the SettlementChainParameterRegistry key `xmtp.payerRegistry.feeDistributor` with the new `DistributionManager` proxy address. It then calls `PayerRegistry.updateFeeDistributor()` to update the fee distributor in the `PayerRegistry` contract.
```
ENVIRONMENT=testnet-staging forge script DeployPayerReportManagerScript --rpc-url base_sepolia --slow --sig "updateDependencies()" --broadcast
```


## STAGE 3 - Code Verification
To verify the code of the new implementations:
```
forge verify-contract --chain-id 84532 <newly deployed payer report manager implementation address> src/settlement-chain/PayerReportManager.sol:PayerReportManager
forge verify-contract --chain-id 84532 <newly deployed distribution manager implementation address> src/settlement-chain/DistributionManager.sol:DistributionManager
```
