# Deployment

The project includes deploy and upgrade scripts.

## Deploying Base Contract

The `FeeToken` is a singleton with respect to the app chain, regardless of environment, and the `FeeToken` relies on a single `ParameterRegistry`. Further, the `Factory` is also a singleton on each chain as it enables deterministic and consistent addresses across all chains, and it also relies on a single `ParameterRegistry`. And lastly, the `Gateway` is also a singleton on each chain as it not only relies on a single `ParameterRegistry`, but also relays parameters between settlement chain and app chain parameter registries.

Because of this, for each settlement chain, regardless of environment, a set of base contracts must be deployed only once for each settlement chain. This deployment includes the `Factory`, `SettlementChaiParameterRegistry`, `FeeToken` (and `MockUnderlyingFeeToken` if it is a testnet), and `SettlementChainGateway` for the settlement chain, and the `Factory`, `AppChainParameterRegistry`, and `AppChainGateway` for the app chain.

These are deployed via:

```shell
./dev/deploy-base <CHAIN_NAME>
```

They are verified via:

```shell
./dev/verify-base <CHAIN_NAME> basescan
./dev/verify-base <CHAIN_NAME> blockscout
```

<!-- TODO: Add script and documentation for setting the inbox address for the settlement chain gateway -->

## Deploying Environment Contracts

This deployment includes the `PayerRegistry`, `RateRegistry`, `NodeRegistry`, `PayerReportManager`, `DistributionManager`, and `DepositSplitter` for the settlement chain, and the `GroupMessageBroadcaster`, `IdentityUpdateBroadcaster` for the app chain.

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

They are bridged via:

```shell
./dev/bridge-starting-parameters <ENVIRONMENT>
```

The parameters are applied at each contract via:

```shell
./dev/update-starting-parameters <ENVIRONMENT> settlement-chain
./dev/update-starting-parameters <ENVIRONMENT> app-chain
```
