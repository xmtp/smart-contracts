# XMTP Contracts

- [XMTP Contracts](#xmtp-contracts)
  - [Usage](#usage)
    - [Prerequisites](#prerequisites)
    - [Initialize project](#initialize-project)
  - [Developer tools](#developer-tools)
  - [Forge scripts](#forge-scripts)

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
npm install  # if using node
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

## Forge scripts

The project includes deployer and upgrade scripts.

Current available configuration options:

```shell
PRIVATE_KEY=0x000000000000000000000000000000000000dEaD
XMTP_GROUP_MESSAGE_BROADCASTER_ADMIN_ADDRESS=0x000000000000000000000000000000000000dEaD
XMTP_IDENTITY_UPDATE_BROADCASTER_ADMIN_ADDRESS=0x000000000000000000000000000000000000dEaD
XMTP_NODE_REGISTRY_ADMIN_ADDRESS=0x000000000000000000000000000000000000dEaD
XMTP_RATES_MANAGER_ADMIN_ADDRESS=0x000000000000000000000000000000000000dEaD
```
