# XMTP network contracts - deployment

- [XMTP network contracts - deployment](#xmtp-network-contracts---deployment)
  - [Base contracts](#base-contracts)
    - [Constraints](#constraints)
    - [Deploy base contracts](#deploy-base-contracts)
  - [Environment contracts](#environment-contracts)
    - [Deploy environment contracts](#deploy-environment-contracts)

The project includes deploy and upgrade scripts.

## Base contracts

### Constraints

- The `FeeToken` must be a singleton contract with respect to all XMTP App Chains that use it as their underlying gas token, so its deployment on a blockchain is not per-environment, but rather per set of XMTP App Chains that roll up to the XMTP Settlement Chain. The `FeeToken` relies on a single `ParameterRegistry` on the XMTP Settlement Chain (i.e., for migration purposes).

- The `Gateway` must be a singleton contract with respect to all XMTP App Chains in an environment, and handles bridging parameters and the Fee Token between a single `ParameterRegistry` on its chain and the `ParameterRegistry` on the XMTP App Chains. It also relies on a single `ParameterRegistry` (i.e., for migration purposes).

- The `Factory` must be a singleton contract with respect to a set of contracts in an environment (i.e., for the `FeeToken`, `ParameterRegistry`, and `Gateway`) to deploy them at deterministic and consistent addresses across all chains. It also relies on a single `ParameterRegistry` (i.e., for migration purposes).

- The `ParameterRegistry` must be a singleton contract with respect to a set of contracts in an environment (i.e., for the `FeeToken`, `Factory`, and `Gateway`) to be a source of administrated parameter values.

Because of the above, for each XMTP Settlement Chain, regardless of environment, a set of base contracts must be deployed only once. This deployment includes the `Factory`, `SettlementChainParameterRegistry`, `FeeToken` (and `MockUnderlyingFeeToken` if it is a testnet), and `SettlementChainGateway` for the XMTP Settlement Chain, and the `Factory`, `AppChainParameterRegistry`, and `AppChainGateway` for the XMTP App Chain. These are called the "base contracts" because they are the base contracts that are required before any environment-specific contracts are deployed.

### Deploy base contracts

These base contracts are deployed via:

```shell
./dev/deploy-base <CHAIN_NAME>
```

They are verified via:

```shell
./dev/verify-base <CHAIN_NAME> basescan
./dev/verify-base <CHAIN_NAME> blockscout
```

## Environment contracts

This deployment includes the `PayerRegistry`, `RateRegistry`, `NodeRegistry`, `PayerReportManager`, `DistributionManager`, and `DepositSplitter` for the XMTP Settlement Chain, and the `GroupMessageBroadcaster`, `IdentityUpdateBroadcaster` for the XMTP App Chain.

### Deploy environment contracts

These are deployed via:

```shell
./dev/deploy <ENVIRONMENT> settlement-chain
./dev/deploy <ENVIRONMENT> app-chain
```

They are verified via:

```shell
./dev/verify <ENVIRONMENT> settlement-chain basescan
./dev/verify <ENVIRONMENT> settlement-chain blockscout
./dev/verify <ENVIRONMENT> app-chain alchemy
```

The starting parameters are defined via:

```shell
./dev/set-starting-parameters <ENVIRONMENT>
```

The parameters are applied at each XMTP Settlement Chain contract via:

```shell
./dev/update-starting-parameters <ENVIRONMENT> settlement-chain
```

Some parameters are bridged to the XMTP App Chain via:

```shell
./dev/bridge-starting-parameters <ENVIRONMENT>
```

The parameters are applied at each XMTP App Chain contract via:

```shell
./dev/update-starting-parameters <ENVIRONMENT> app-chain
```
