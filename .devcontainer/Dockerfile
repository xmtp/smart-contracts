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

# Install yarn classic to match local dev environment
RUN npm install -g yarn@1.22.22 \
    && yarn --version

# Install slither directly to /usr/local/bin; PIPX_HOME ensures the venv is world-readable
RUN PIPX_HOME=/usr/local/pipx PIPX_BIN_DIR=/usr/local/bin pipx install slither-analyzer==${SLITHER_VERSION} \
    && slither --version

# Install foundry directly to /usr/local/bin (FOUNDRY_DIR=/usr/local puts binaries in /usr/local/bin)
RUN export FOUNDRY_DIR=/usr/local \
    && curl -L https://foundry.paradigm.xyz | bash \
    && foundryup --install ${FOUNDRY_VERSION} \
    && forge --version

USER vscode
