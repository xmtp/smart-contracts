#!/bin/bash
set -euo pipefail

export source_dir="${SOURCE_DIR:-src}"
export build_dir="${BUILD_DIR:-build}"
export artifacts_dir="${OUTPUT_DIR:-artifacts}"
export bytecode_dir="${artifacts_dir}/bytecode"
export abi_dir="${artifacts_dir}/abi"
export info_file="${artifacts_dir}/buildinfo.json"
export forge_version=$(forge --version | grep "Version" | awk '{print $3}')

script_dir=$(dirname "$(realpath "$0")")
repo_root=$(realpath "${script_dir}/../")
cd "${repo_root}"

mkdir -p "${build_dir}" "${artifacts_dir}" "${bytecode_dir}" "${abi_dir}"

function generate_artifacts() {
    local filename="$1"
    local package="$(echo "${filename}" | tr '[:upper:]' '[:lower:]')"
    local source_artifact="${source_dir}/${filename}.sol"
    local bytecode_artifact="${bytecode_dir}/${filename}.bin.json"
    local abi_artifact="${abi_dir}/${filename}.abi.json"

    rm -f "${bytecode_artifact}" "${abi_artifact}"

    # Generate ABI and bytecode
    if ! forge inspect "${source_artifact}:${filename}" abi --json > "${abi_artifact}"; then
        echo "ERROR: Failed to generate ABI for ${filename}" >&2
        exit 1
    fi

    if ! forge inspect "${source_artifact}:${filename}" bytecode > "${bytecode_artifact}"; then
        echo "ERROR: Failed to generate bytecode for ${filename}" >&2
        exit 1
    fi
}

function build_info() {
    local build_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local build_tag=$(git describe HEAD --tags --long)

    echo "{\"forge_version\": \"${forge_version}\",\"date\": \"${build_date}\", \"tag\": \"${build_tag}\"}" > "${info_file}"
}

function main() {
    echo "Generating artifacts with forge version ${forge_version}"

    # Define contracts (pass as arguments or use a default list)
    local contracts=("$@")
    if [ "${#contracts[@]}" -eq 0 ]; then
        contracts=("GroupMessageBroadcaster" "IdentityUpdateBroadcaster" "NodeRegistry" "RateRegistry")
    fi

    for contract in "${contracts[@]}"; do
        echo "⧖ Generating artifacts for contract: ${contract}"
        generate_artifacts "${contract}"
    done

    build_info

    echo -e "\033[32m✔\033[0m Artifacts generated successfully!\n"
}

if [ "${forge_version}" != "1.0.0-v1.0.0" ]; then
    echo "ERROR: Forge version must be v1.0.0" >&2
    exit 1
fi

main "$@"
