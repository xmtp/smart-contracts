# BUILDER IMAGE
ARG GO_VERSION=1.24
ARG FOUNDRY_VERSION=1.0.0
FROM golang:${GO_VERSION}-bookworm AS builder

WORKDIR /build

SHELL ["/bin/bash", "-c"]

RUN apt-get update &&  \
    apt-get install -y curl jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -L https://foundry.paradigm.xyz | bash && \
    source ~/.bashrc && \
    foundryup -i "${FOUNDRY_VERSION}" &&  \
    cp ~/.foundry/bin/* /usr/local/bin

COPY . .

RUN chmod +x ./dev/gen-anvil-state \
    && ./dev/gen-anvil-state

# ACTUAL IMAGE

FROM ghcr.io/foundry-rs/foundry

LABEL maintainer="eng@ephemerahq.com"
LABEL source="https://github.com/xmtp/smart-contracts"
LABEL description="XMTP Contracts Image"

EXPOSE 8545

COPY --from=builder /build/deployments/anvil_localnet/anvil-state.json anvil-state.json
COPY --from=builder /build/deployments/anvil_localnet/anvil-state-info.json anvil-state-info.json

ENTRYPOINT [ "anvil", "--host", "0.0.0.0", "--mixed-mining", "--block-time", "1", "--load-state", "anvil-state.json" ]
