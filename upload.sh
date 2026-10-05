#!/usr/bin/env bash

set -euo pipefail

api_url="${STIGMERGY_API_URL:-http://127.0.0.1:8080}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
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

while IFS= read -r -d '' file; do
    kind=$(yq e -r '.kind // ""' "$file")
    name=$(yq e -r '.metadata.name // ""' "$file")
    if [[ -z "$kind" || -z "$name" ]]; then
        echo "Manifest $file must define kind and metadata.name" >&2
        exit 1
    fi
    collection=$(collection_for_kind "$kind")
    payload=$(yq e '.' "$file")
    # Local reusable variables are expanded before upload, not new API fields.
    reference=$(yq e -r '.spec.groupVarsRef.name // ""' "$file")
    if [[ -n "$reference" ]]; then
        [[ "$kind" == InventoryCaptureGroup && "$reference" =~ ^[a-z0-9][-a-z0-9]*-group-vars$ ]] || { echo 'Invalid local group-vars reference' >&2; exit 1; }
        variables_file="$script_dir/GroupVars/${reference%-group-vars}.yml"
        [[ -f "$variables_file" ]] || { echo "Missing local variables file: $variables_file" >&2; exit 1; }
        payload=$(GROUP_VARS_FILE="$variables_file" yq e '.spec.groupVars = (load(strenv(GROUP_VARS_FILE)) * (.spec.groupVarsRef | del(.name))) | del(.spec.groupVarsRef)' "$file")
    fi
    echo "Applying $kind/$name"
    printf '%s\n' "$payload" | curl --fail --silent --show-error --output /dev/null \
        "${auth_headers[@]}" \
        --request PUT \
        --header 'Content-Type: application/yaml' \
        --data-binary @- \
        "$api_url/api/v1alpha1/$collection/$name" \
        3<<< "Authorization: Bearer ${STIGMERGY_API_TOKEN:-}"
done < <(find "$script_dir" -mindepth 2 -maxdepth 2 -type f -name '*.yaml' -print0 | sort -z)
