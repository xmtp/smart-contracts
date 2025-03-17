# XMTP Contracts

-   [XMTP Contracts](#xmtp-contracts)
    -   [Messaging Contracts](#messaging-contracts)
    -   [Node Registry](#node-registry)
    -   [Usage](#usage)
        -   [Prerequisites](#prerequisites)
        -   [Install](#install)
        -   [Test](#test)
        -   [Run static analysis](#run-static-analysis)
    -   [Scripts](#scripts)
        -   [Messages contracts](#messaging-contracts-1)
        -   [Node registry](#node-registry)

**⚠️ Experimental:** This software is in early development. Expect frequent changes and unresolved issues.

This repository contains all the smart contracts that underpin the XMTP decentralized network.

## Messaging Contracts

The messaging contracts `GroupMessageBroadcaster` and `IdentityUpdateBroadcaster` respectively manage the broadcasting for `GroupMessages` and `IdentityUpdates` sent by clients to the network.

## Node Registry

The `NodeRegistry` maintains a record of all node operators participating in the XMTP network. This registry serves as a source of truth for the network's active node participants, contributing to the network's integrity.

The registry is currently implemented following the [ERC721](https://eips.ethereum.org/EIPS/eip-721) standard.

## Usage

The project is built with the `Foundry` framework, and dependency management is handled using native git submodules.

Additionally, it uses `slither` for static analysis.

### Prerequisites

[Install foundry](https://book.getfoundry.sh/getting-started/installation)

[Install slither](https://github.com/crytic/slither?tab=readme-ov-file#how-to-install)

### Install

As the project uses `foundry`, update the dependencies by running:

```shell
forge update
```

Build the contracts:

```shell
forge build
```

### Test

To run the unit tests:

```shell
forge test
```

### Run static analysis

Run the analysis with `slither`:

```shell
slither .
```

## Scripts

The project includes deployer and upgrade scripts.

### Messaging contracts

-   Configure the environment by creating an `.env` file, with this content:

```shell
### Main configuration
PRIVATE_KEY=0xYourPrivateKey # Private key of the EOA deploying the contracts

### XMTP deployment configuration
XMTP_GROUP_MESSAGE_BROADCASTER_ADMIN_ADDRESS=0x12345abcdf # the EOA assuming the admin role in the GroupMessageBroadcaster contract.
XMTP_IDENTITY_UPDATE_BROADCASTER_ADMIN_ADDRESS=0x12345abcdf # the EOA assuming the admin role in the IdentityUpdateBroadcaster contract.
```

-   Run the desired script with:

```shell
forge script --rpc-url <RPC_URL> --broadcast <PATH_TO_SCRIPT>
```

Example:

```shell
forge script --rpc-url http://localhost:7545 --broadcast script/DeployGroupMessages.s.sol
```

The scripts output the deployment and upgrade in the `output` folder.

### Node registry

**⚠️:** The node registry hasn't been fully migrated to forge scripts.

-   Deploy with `forge create`:

```shell
forge create --broadcast --legacy --json --rpc-url $RPC_URL --private-key $PRIVATE_KEY "src/NodeRegistry.sol:NodeRegistry"
```
