# Start from a base image with Foundry installed
ARG FOUNDRY_VERSION=1.0.0

FROM ghcr.io/foundry-rs/foundry:v${FOUNDRY_VERSION} AS builder

WORKDIR /build

SHELL ["/bin/bash", "-c"]

USER root

# Install Node.js and npm
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

USER foundry

ENV ANVIL_RPC_URL=http://localhost:8545

# Copy your project files into the image
COPY . .

RUN ./dev/gen-anvil-state

FROM ghcr.io/foundry-rs/foundry

LABEL maintainer="eng@ephemerahq.com"
LABEL source="https://github.com/xmtp/smart-contracts"
LABEL description="XMTP Contracts Image"

EXPOSE 8545

COPY --from=builder /build/anvil-state.json anvil-state.json

ENTRYPOINT [ "anvil", "--host", "0.0.0.0", "--mixed-mining", "--block-time", "1", "--load-state", "anvil-state.json" ]