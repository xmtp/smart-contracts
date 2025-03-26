#!/bin/bash
set -euo pipefail

script_dir=$(dirname "$(realpath "$0")")
repo_root=$(realpath "${script_dir}/../")
cd "${repo_root}"

source "${script_dir}/lib/common"
source "${script_dir}/lib/default.env"

mkdir -p "${anvil_config_dir}"

function kill_anvil() {
    echo "⧖ Killing existing anvil instance"
    pkill -f anvil
}

function start_anvil() {
    kill_anvil && sleep 1
    echo "⧖ Starting anvil"
    anvil --dump-state "${anvil_state_file}" &> /dev/null 2>&1 &
    sleep 1
}

function deploy_contracts() {
    echo "⧖ Deploying contracts"
    forge script script/DeployRatesManager.s.sol --broadcast --rpc-url "${APP_CHAIN_RPC_URL}" &> /dev/null 2>&1
    forge script script/DeployNodeRegistry.s.sol --broadcast --rpc-url "${APP_CHAIN_RPC_URL}" &> /dev/null 2>&1
    forge script script/DeployGroupMessageBroadcaster.s.sol --broadcast --rpc-url "${APP_CHAIN_RPC_URL}" &> /dev/null 2>&1
    forge script script/DeployIdentityUpdateBroadcaster.s.sol --broadcast --rpc-url "${APP_CHAIN_RPC_URL}" &> /dev/null 2>&1
}

function dump_state_info() {
    echo "⧖ Dumping anvil state info to ${anvil_state_info_file}"
    local rate_registry_address=$(jq -r ".addresses.proxy" "${anvil_config_dir}/RateRegistry.json")
    local message_group_broadcaster_address=$(jq -r ".addresses.proxy" "${anvil_config_dir}/GroupMessageBroadcaster.json")
    local identity_update_broadcaster_address=$(jq -r ".addresses.proxy" "${anvil_config_dir}/IdentityUpdateBroadcaster.json")
    local node_registry_address=$(jq -r ".addresses.implementation" "${anvil_config_dir}/NodeRegistry.json")

    jq -n \
      --arg rate_registry "$rate_registry_address" \
      --arg message_group_broadcaster "$message_group_broadcaster_address" \
      --arg identity_update_broadcaster "$identity_update_broadcaster_address" \
      --arg node_registry "$node_registry_address" \
      '{
        rate_registry_address: $rate_registry,
        message_group_broadcaster_address: $message_group_broadcaster,
        identity_update_broadcaster_address: $identity_update_broadcaster,
        node_registry_address: $node_registry
      }' > "${anvil_state_info_file}"
}

if [ ! command -v anvil &> /dev/null ]; then
    echo "ERROR: anvil could not be found"
    exit 1
fi

start_anvil
deploy_contracts
dump_state_info
kill_anvil

echo -e "\033[32m✔\033[0m Anvil state saved to ${anvil_state_file}"
