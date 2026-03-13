#!/usr/bin/env bash
set -euo pipefail

echo "==> Initializing git submodules..."
git submodule update --init --recursive

echo "==> Installing Node.js dependencies..."
yarn install --frozen-lockfile

echo "==> Building contracts..."
forge build

echo "==> Dev container ready!"
echo "    forge $(forge --version 2>&1 | head -1)"
echo "    node  $(node --version)"
echo "    yarn  $(yarn --version)"
