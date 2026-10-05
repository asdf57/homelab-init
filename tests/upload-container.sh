#!/usr/bin/env bash
set -euo pipefail
[[ -f /.dockerenv ]] || { echo 'Run inside a disposable runner container' >&2; exit 1; }
workspace=$(mktemp -d)
mkdir -p "$workspace/bin"
cp -a /configuration "$workspace/configuration"
export UPLOAD_CAPTURE="$workspace/captured.yaml"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'IFS= read -r header <&3' \
    '[[ "$header" == "Authorization: Bearer upload-test-token-01234567890123456789" ]]' \
    '[[ "$*" != *"upload-test-token"* ]]' \
    'printf "%s\n" "---" >> "$UPLOAD_CAPTURE"' \
    'cat >> "$UPLOAD_CAPTURE"' > "$workspace/bin/curl"
chmod 0755 "$workspace/bin/curl"
export PATH="$workspace/bin:$PATH"
export STIGMERGY_API_TOKEN=upload-test-token-01234567890123456789
bash "$workspace/configuration/upload.sh"
[[ $(yq e 'select(.kind == "InventoryCaptureGroup" and .metadata.name == "servers") | .spec.groupVars.all.ansible_user' "$UPLOAD_CAPTURE") == ansible ]]
[[ $(yq e 'select(.kind == "InventoryCaptureGroup" and .metadata.name == "servers") | .spec.groupVars.workstations.desktop_environment' "$UPLOAD_CAPTURE") == true ]]
! grep -Eq 'groupVarsRef:|mgmtUser:|name: build-isos' "$UPLOAD_CAPTURE"
[[ -z $(yq e 'select(.kind == "SSHKeyPair" and .metadata.name == "ansible-mgmt") | .metadata.name' "$UPLOAD_CAPTURE") ]]
[[ $(yq e 'select(.kind == "Command" and .metadata.name == "servers") | .spec.commandsPipelineRef.name' "$UPLOAD_CAPTURE") == servers ]]
[[ $(yq e 'select(.kind == "CommandsPipeline" and .metadata.name == "ssh-trust") | .spec.commandTemplate.ttlSecondsAfterFinished' "$UPLOAD_CAPTURE") == 86400 ]]
! grep -Eq 'commandPath:|kind: CommandInventory' "$UPLOAD_CAPTURE"
[[ -z $(yq e 'select(.kind == "Command" and .metadata.name == "ssh-trust") | .metadata.name' "$UPLOAD_CAPTURE") ]]
echo 'PASS: authenticated manifest rendering, reusable generic variables, no obsolete Pipeline'
