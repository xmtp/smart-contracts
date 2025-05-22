# Start from a base image with Foundry installed
ARG FOUNDRY_VERSION=1.2.0

FROM ghcr.io/foundry-rs/foundry:v${FOUNDRY_VERSION} AS builder

WORKDIR /build

SHELL ["/bin/bash", "-c"]

USER root

# Install Node.js and npm
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get install -y jq && \
    apt-get install -y sed && \
    apt-get install -y xxd && \
    apt-get install -y gzip && \
    node -v && npm -v

USER foundry

# Copy your project files into the image
COPY . .

RUN ./dev/gen-anvil-state

FROM ghcr.io/foundry-rs/foundry:v${FOUNDRY_VERSION}

LABEL maintainer="eng@ephemerahq.com"
LABEL source="https://github.com/xmtp/smart-contracts"
LABEL description="XMTP Contracts Image"

WORKDIR /blockchain

USER root

RUN apt-get update && \
    apt-get install -y curl

EXPOSE 8545

COPY --from=builder /build/anvil-state-load-data.json ./anvil-state-load-data.json
COPY --from=builder /build/dev/start-anvil-with-state ./start-anvil-with-state
# COPY --from=builder /build/dev/start-anvil-and-load-state ./start-anvil-and-load-state

RUN chmod +x ./start-anvil-with-state
# RUN chmod +x ./start-anvil-and-load-state

ENTRYPOINT ["./start-anvil-with-state"]
CMD ["--load-state", "./anvil-state-load-data.json", "--host", "0.0.0.0", "--mixed-mining", "--block-time", "1"]
