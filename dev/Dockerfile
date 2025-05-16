ARG FOUNDRY_VERSION=1.0.0

FROM ghcr.io/foundry-rs/foundry:v${FOUNDRY_VERSION}

LABEL maintainer="eng@ephemerahq.com"
LABEL source="https://github.com/xmtp/smart-contracts"
LABEL description="XMTP Contracts Image"

EXPOSE 8545

COPY anvil-state.json anvil-state.json

ENTRYPOINT [ "anvil", "--host", "0.0.0.0", "--mixed-mining", "--block-time", "1", "--load-state", "anvil-state.json" ]