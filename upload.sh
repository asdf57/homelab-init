#!/usr/bin/env bash

set -euo pipefail

api_url="${STIGMERGY_API_URL:-http://127.0.0.1:8080}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Arch hosts may provide the Python jq-wrapper; runners use Mike Farah yq.
if yq --version 2>&1 | grep -qi 'mikefarah'; then
    yaml_json() { yq e -o=json '.' "$1"; }
else
    yaml_json() { yq '.' "$1"; }
fi
command -v jq >/dev/null || { echo 'jq is required' >&2; exit 1; }

# With no arguments, apply all site manifests. Arguments select individual files.
files=("$@")
if (( ${#files[@]} == 0 )); then
    mapfile -d '' -t files < <(find "$script_dir" -mindepth 2 -maxdepth 2 -type f -name '*.yaml' -print0 | sort -z)
fi

auth_headers=()
if [[ -n "${STIGMERGY_API_TOKEN:-}" ]]; then
    [[ "$STIGMERGY_API_TOKEN" != *$'\n'* && "$STIGMERGY_API_TOKEN" != *$'\r'* ]] || { echo 'Invalid API token' >&2; exit 1; }
    auth_headers+=(--header @/dev/fd/3)
fi

collection_for_kind() {
    local kebab
    kebab=$(printf '%s' "$1" \
        | sed -E 's/([A-Z]+)([A-Z][a-z])|([a-z0-9])([A-Z])/\1\3-\2\4/g' \
        | tr '[:upper:]' '[:lower:]')
    case "$kebab" in
        *y) printf '%sies\n' "${kebab%y}" ;;
        *)  printf '%ss\n' "$kebab" ;;
    esac
}

for file in "${files[@]}"; do
    payload=$(yaml_json "$file")
    kind=$(jq -r '.kind // ""' <<< "$payload")
    name=$(jq -r '.metadata.name // ""' <<< "$payload")
    if [[ -z "$kind" || -z "$name" ]]; then
        echo "Manifest $file must define kind and metadata.name" >&2
        exit 1
    fi
    [[ "$kind" != ProvisioningRun ]] || { echo 'ProvisioningRun requests must be created explicitly through the API/UI' >&2; exit 1; }
    collection=$(collection_for_kind "$kind")
    # Local reusable variables are expanded before upload, not new API fields.
    reference=$(jq -r '.spec.groupVarsRef.name // ""' <<< "$payload")
    if [[ -n "$reference" ]]; then
        [[ "$kind" == InventoryCaptureGroup && "$reference" =~ ^[a-z0-9][-a-z0-9]*-group-vars$ ]] || { echo 'Invalid local group-vars reference' >&2; exit 1; }
        variables_file="$script_dir/GroupVars/${reference%-group-vars}.yml"
        [[ -f "$variables_file" ]] || { echo "Missing local variables file: $variables_file" >&2; exit 1; }
        variables=$(yaml_json "$variables_file")
        payload=$(jq --argjson variables "$variables" '.spec.groupVars = ($variables * (.spec.groupVarsRef | del(.name))) | del(.spec.groupVarsRef)' <<< "$payload")
    fi
    echo "Applying $kind/$name"
    printf '%s\n' "$payload" | curl --fail --silent --show-error --output /dev/null \
        "${auth_headers[@]}" \
        --request PUT \
        --header 'Content-Type: application/json' \
        --data-binary @- \
        "$api_url/api/v1alpha1/$collection/$name" \
        3<<< "Authorization: Bearer ${STIGMERGY_API_TOKEN:-}"
done
