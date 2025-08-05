# XMTP Contracts

- [XMTP Contracts](#xmtp-contracts)
  - [Usage](#usage)
    - [Prerequisites](#prerequisites)
    - [Initialize project](#initialize-project)
  - [Developer tools](#developer-tools)
  - [Scripts](#scripts)

**⚠️ Experimental:** This software is in early development. Expect frequent changes and unresolved issues.

This repository contains all the smart contracts that underpin the XMTP decentralized network.

Contracts documentation can be found [here](https://ephemerahq.notion.site/XMTP-Contracts-directory-18530823ce928017996efaa52ac248cd).

[![Solidity](https://github.com/xmtp/smart-contracts/actions/workflows/solidity.yml/badge.svg)](https://github.com/xmtp/smart-contracts/actions/workflows/solidity.yml)

## Usage

The project is built with the `Foundry` framework, and dependency management is handled using native git submodules.

Additionally, it uses `slither` for static analysis.

### Prerequisites

[Install foundry](https://book.getfoundry.sh/getting-started/installation)

[Install slither](https://github.com/crytic/slither?tab=readme-ov-file#how-to-install)

[Install node](https://nodejs.org/)

[Install prettier](https://prettier.io/docs/install)

Optionally, [install yarn](https://classic.yarnpkg.com/lang/en/docs/install/#mac-stable) or any other preferred JS package manager.

### Initialize project

Initialize the project dependencies:

```shell
yarn install # if using yarn
```

Initialize foundry:

```shell
forge update
```

## Developer tools

The following can be run using `npm`, `yarn` and similar JS package managers.

```text
# Forge scripts
build:          Builds the contracts.
test:           Tests the contracts.
clean:          Cleans the forge environment.
coverage:       Shows the test coverage.
gas-report:     Shows the gas costs.
doc:            Serves the project documentation at http://localhost:4000

# Static analysis
slither:        Runs slither static analysis.

# Linters
solhint:        Runs solhint.
solhint-fix:    Runs solhint in fix mode, potentially modifying files.
lint-staged:    Runs linters only on files that are staged in git.

# Formatters
prettier:       Runs prettier in write mode, potentially modifying files.
prettier-check: Runs prettier in check mode.
```

## Scripts

The project includes deploy and upgrade scripts.

### Deploying Base Contract

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

### Deploying Environment Contracts

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
