#!/usr/bin/env bash
set -euo pipefail
configuration=${UPLOAD_CONFIGURATION:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
workspace=$(mktemp -d)
mkdir -p "$workspace/bin"
cp -a "$configuration" "$workspace/configuration"
export UPLOAD_CAPTURE="$workspace/captured.yaml"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'IFS= read -r header <&3' \
    '[[ "$header" == "Authorization: Bearer upload-test-token-01234567890123456789" ]]' \
    '[[ "$*" != *"upload-test-token"* ]]' \
    'cat >> "$UPLOAD_CAPTURE"' > "$workspace/bin/curl"
chmod 0755 "$workspace/bin/curl"
export PATH="$workspace/bin:$PATH"
export STIGMERGY_API_TOKEN=upload-test-token-01234567890123456789
bash "$workspace/configuration/upload.sh"
[[ $(jq -sr '.[] | select(.kind == "InventoryCaptureGroup" and .metadata.name == "servers") | .spec.groupVars.all.ansible_user' "$UPLOAD_CAPTURE") == ansible ]]
[[ $(jq -sr '.[] | select(.kind == "InventoryCaptureGroup" and .metadata.name == "servers") | .spec.groupVars.workstations.desktop_environment' "$UPLOAD_CAPTURE") == true ]]
! grep -Eq '"groupVarsRef"|"mgmtUser"|"name": "build-isos"' "$UPLOAD_CAPTURE"
[[ -z $(jq -sr '.[] | select(.kind == "SSHKeyPair" and .metadata.name == "ansible-mgmt") | .metadata.name' "$UPLOAD_CAPTURE") ]]
[[ $(jq -sr '.[] | select(.kind == "Command" and .metadata.name == "servers") | .spec.commandsPipelineRef.name' "$UPLOAD_CAPTURE") == servers ]]
[[ $(jq -sr '.[] | select(.kind == "Pipeline" and .metadata.name == "reconcile-ssh-host-keys-ssh-managed") | .spec.externalName' "$UPLOAD_CAPTURE") == reconcile-ssh-host-keys-ssh-managed ]]
! grep -Eq '"commandPath"|"kind": "CommandInventory"' "$UPLOAD_CAPTURE"
[[ -z $(jq -sr '.[] | select(.kind == "Command" and .metadata.name == "ssh-trust") | .metadata.name' "$UPLOAD_CAPTURE") ]]
# A targeted upload must issue exactly one request for the selected Server.
: > "$UPLOAD_CAPTURE"
bash "$workspace/configuration/upload.sh" "$workspace/configuration/Server/server-lima.yaml"
[[ $(jq -s 'length' "$UPLOAD_CAPTURE") == 1 ]]
[[ $(jq -r '.metadata.name' "$UPLOAD_CAPTURE") == zima ]]
# Destructive requests are never accepted as initialization inputs.
printf '%s\n' 'kind: ProvisioningRun' 'metadata: {name: forbidden}' > "$workspace/run.yaml"
if bash "$workspace/configuration/upload.sh" "$workspace/run.yaml"; then
    echo 'ProvisioningRun upload unexpectedly succeeded' >&2
    exit 1
fi
[[ $(jq -s 'length' "$UPLOAD_CAPTURE") == 1 ]]
echo 'PASS: authenticated manifest rendering, reusable generic variables, no obsolete Pipeline'
