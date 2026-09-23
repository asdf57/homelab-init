#!/usr/bin/env bash

set -euo pipefail

api_url="${STIGMERGY_API_URL:-http://127.0.0.1:8080}"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

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
    echo "Applying $kind/$name"
    curl --fail-with-body \
        --request PUT \
        --header 'Content-Type: application/yaml' \
        --data-binary @"$file" \
        "$api_url/api/v1alpha1/$collection/$name"
done < <(find "$script_dir" -mindepth 2 -maxdepth 2 -type f -name '*.yaml' -print0 | sort -z)
