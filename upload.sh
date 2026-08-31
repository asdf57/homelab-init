#!/usr/bin/env bash


# Upload all GitRepository resources
for file in GitRepository/*.yaml; do
    echo "Uploading GitRepository resource from $file"
    curl --fail-with-body \
        -H 'Content-Type: application/yaml' \
        --data-binary @"$file" \
        http://127.0.0.1:8080/api/v1alpha1/git-repositories
done

for file in InventoryCaptureGroup/*.yaml; do
    echo "Uploading InventoryCaptureGroup resource from $file"
    curl --fail-with-body \
        -X POST http://127.0.0.1:8080/api/v1alpha1/inventory-capture-groups \
        -H 'Content-Type: application/yaml' \
        --data-binary @"$file"
done

for file in InventoryPublication/*.yaml; do
    echo "Uploading InventoryPublication resource from $file"
    curl --fail-with-body \
        -H 'Content-Type: application/yaml' \
        --data-binary @"$file" \
        http://127.0.0.1:8080/api/v1alpha1/inventory-publications
done

for file in SecretStore/*.yaml; do
    echo "Uploading SecretStore resource from $file"
    curl --fail-with-body \
        -X POST http://127.0.0.1:8080/api/v1alpha1/secret-stores \
        -H 'Content-Type: application/yaml' \
        --data-binary @"$file"
done

for file in MachineReport/*.yaml; do
    echo "Uploading MachineReport resource from $file"
    curl --fail-with-body \
        -X POST http://127.0.0.1:8080/api/v1alpha1/machine-reports \
        -H 'Content-Type: application/yaml' \
        --data-binary @"$file"
done

for file in Server/*.yaml; do
    echo "Uploading Server resource from $file"
    curl --fail-with-body \
        -X POST http://127.0.0.1:8080/api/v1alpha1/servers \
        -H 'Content-Type: application/yaml' \
        --data-binary @"$file"
done

for file in SSHAccessGrant/*.yaml; do
    echo "Uploading SSHAccessGrant resource from $file"
    curl --fail-with-body \
        -X POST http://127.0.0.1:8080/api/v1alpha1/ssh-access-grants \
        -H 'Content-Type: application/yaml' \
        --data-binary @"$file"
done
