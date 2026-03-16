FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG FOUNDRY_VERSION=1.3.5
ARG NODE_MAJOR=23
ARG SLITHER_VERSION=0.11.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    xxd \
    gzip \
    lcov \
    python3 \
    python3-pip \
    pipx \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare yarn@stable --activate

RUN PIPX_BIN_DIR=/usr/local/bin pipx install slither-analyzer==${SLITHER_VERSION}

RUN curl -L https://foundry.paradigm.xyz | bash \
    && /root/.foundry/bin/foundryup --version ${FOUNDRY_VERSION} \
    && ln -sf /root/.foundry/bin/forge /usr/local/bin/forge \
    && ln -sf /root/.foundry/bin/cast /usr/local/bin/cast \
    && ln -sf /root/.foundry/bin/anvil /usr/local/bin/anvil \
    && ln -sf /root/.foundry/bin/chisel /usr/local/bin/chisel
