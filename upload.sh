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
upload_resources MachineReport MachineReport machine-reports
upload_resources Server Server servers
upload_resources SSHAccessGrant SSHAccessGrant ssh-access-grants
upload_resources Secret Secret secrets

secret_exists=$(curl --silent --fail-with-body --request GET "$api_url/api/v1alpha1/secrets/git-ssh-key" || true)

# REsponse would be: {"error":{"code":"NotFound","message":"resource not found: Secret \"git-ssh-key\""}}

secret_has_error=$(echo "$secret_exists" | jq -r '.error.code // empty')
if [[ -n "$secret_has_error" ]] && [[ "$secret_has_error" != "NotFound" ]]; then
    echo "Error checking for existing secret: $secret_exists" >&2
    exit 1
fi

if [[ -n "$secret_exists" ]] && [[ "$secret_exists" != *"NotFound"* ]]; then
    echo "Secret git-ssh-key already exists. Skipping upload."
else
    echo "Secret git-ssh-key does not exist. Uploading..."

    if [[ ! -f /tmp/git_ssh_key ]]; then
        echo "Generating new SSH key pair for git-ssh-key..."
        ssh-keygen -t ed25519 -f /tmp/git_ssh_key -N "" -C "git-ssh-key"
    fi

    # build the Secret object
    secret_yaml=$(cat <<EOF
apiVersion: homelab.io/v1alpha1
kind: Secret
metadata:
  name: git-ssh-key
spec:
  secretStoreRef:
    name: openbao
  path: bootstrap/git-ssh-key
  data:
    privateKey: |
$(sed 's/^/      /' /tmp/git_ssh_key)
    publicKey: |
$(sed 's/^/      /' /tmp/git_ssh_key.pub)
EOF
)
    curl --fail-with-body \
        --request PUT \
        --header 'Content-Type: application/yaml' \
        --data-binary @<(echo "$secret_yaml") \
        "$api_url/api/v1alpha1/secrets/git-ssh-key"
    echo "Secret git-ssh-key uploaded successfully."
fi
