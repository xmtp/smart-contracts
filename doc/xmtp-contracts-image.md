# XMTP Contracts Image

The XMTP Contracts Image aims to provide a stable containerized environment to help the `xmtpd` development process and test locally.

The image contains a baked anvil instance, where all the necessary contracts for XMTP development are deployed. And two pre-registered nodes that can serve to initialize an `xmtpd` instance.

## Contracts deployed

- [CREATE3Factory](../src/CREATE3Factory.sol)
- [NodeRegistry](../src/NodeRegistry.sol)
- [RateRegistry](../src/RateRegistry.sol)
- [GroupMessageBroadcaster](../src/GroupMessageBroadcaster.sol)
- [IdentityUpdateBroadcaster](../src/IdentityUpdateBroadcaster.sol)

The `CREATE3Factory` is used to deploy all the contracts, all the addresses are deterministically computed.

## Nodes deployed

### Node 1

- Node ID: 100
- Node URL: <http://localhost:5050">
- Node owner address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
- Private key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
- Signing public key: 0x02ba5734d8f7091719471e7f7ed6b9df170dc70cc661ca05e688601ad984f068b0

### Node 2

- Node ID: 200
- Node URL: <http://localhost:5051>
- Node owner address: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
- Private key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
- Signing public key: 0x039d9031e97dd78ff8c15aa86939de9b1e791066a0224e331bc962a2099a7b1f04

## Artifacts

The artifacts included in the image are the following. The paths provided are the full path.

- **anvil state** at `/app/anvil-state.json`

The anvil state can be used to bootstrap an anvil instance as follows:

```shell
anvil --load-state /app/anvil-state.json
```

- **anvil state info file** at `/app/anvil-state-info.json`

The `anvil-state-info.json` file contents are as follows:

```json
{
  "create3_factory_address": "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  "rate_registry_address": "0xE71ac6dE80392495eB52FB1dCa321f5dB8f51BAE",
  "message_group_broadcaster_address": "0xD5b7B43B0e31112fF99Bd5d5C4f6b828259bedDE",
  "identity_update_broadcaster_address": "0xe67104BC93003192ab78B797d120DBA6e9Ff4928",
  "node_registry_address": "0x8d69E9834f1e4b38443C638956F7D81CD04eBB2F"
}
```

By parsing the file, or using `jq`, all the contracts can be accessed programmatically.

## Using the image

A new image is created once per release, and pushed to `ghcr.io/xmtp/contracts:TAG`.

Additionally, an image is created and pushed with every new pull request and is accessible by its sha, or the latest tag.

```shell
docker pull ghcr.io/xmtp/contracts:latest
docker pull ghcr.io/xmtp/contracts:sha-44d1eb4
```

### Locally

To pull the image locally, simply run the following command.

```shell
# Use docker, podman or any other container runtime of choice.
docker pull ghcr.io/xmtp/contracts:latest
```

### As a builder image

To use it as part of a container image build process, add it as `FROM`, as in the next example.

```Dockerfile
FROM ghcr.io/xmtp/contracts:latest

RUN <...>

ENTRYPOINT <...>
```

## Generate a baked anvil state

The anvil state can be manually generated running the following script.

```shell
dev/gen-anvil-state
```

The artifacts will be saved in the deployments folder. Note that path are relative paths from the repository root.

- anvil state at `deployments/anvil_localnet/anvil-state.json`
- anvil state info file at `deployments/anvil_localnet/anvil-state-info.json`
