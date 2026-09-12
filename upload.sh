#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

api_url="${STIGMERGY_API_URL:-http://127.0.0.1:8080}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

upload_resources() {
    local kind=$1
    local directory=$2
    local collection=$3
    local file name
    local -a files=("$script_dir/$directory"/*.yaml)

    if (( ${#files[@]} == 0 )); then
        echo "No $kind manifests found in $script_dir/$directory" >&2
        return 1
    fi

    for file in "${files[@]}"; do
        name=$(awk '
            /^metadata:$/ { in_metadata = 1; next }
            in_metadata && /^  name: / { print $2; exit }
            in_metadata && /^[^ ]/ { in_metadata = 0 }
        ' "$file")
        if [[ -z "$name" ]]; then
            echo "Could not find metadata.name in $file" >&2
            return 1
        fi

        echo "Applying $kind resource $name from $file"
        curl --fail-with-body \
            --request PUT \
            --header 'Content-Type: application/yaml' \
            --data-binary @"$file" \
            "$api_url/api/v1alpha1/$collection/$name"
    done
}

upload_resources GitRepository GitRepository git-repositories
upload_resources InventoryCaptureGroup InventoryCaptureGroup inventory-capture-groups
upload_resources InventoryPublication InventoryPublication inventory-publications
upload_resources SecretStore SecretStore secret-stores
upload_resources SSHKeyPair SSHKeyPair ssh-key-pairs
upload_resources MachineReport MachineReport machine-reports
upload_resources Server Server servers
upload_resources Secret Secret secrets
