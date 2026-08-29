#!/usr/bin/env bash

curl --fail-with-body \
    -X POST http://127.0.0.1:8080/api/v1alpha1/servers \
    -H 'Content-Type: application/yaml' \
    --data-binary @desktop.yaml

curl --fail-with-body \
    -X POST http://127.0.0.1:8080/api/v1alpha1/secret-stores \
    -H 'Content-Type: application/yaml' \
    --data-binary @openbao-secret-store.yaml

curl --fail-with-body \
    -X POST http://127.0.0.1:8080/api/v1alpha1/ssh-access-grants \
    -H 'Content-Type: application/yaml' \
    --data-binary @desktop-matt-ssh.yaml

curl --fail-with-body \
    -X POST http://127.0.0.1:8080/api/v1alpha1/inventory-capture-groups \
    -H 'Content-Type: application/yaml' \
    --data-binary @server-capture-group.yaml

curl --fail-with-body \
    -H 'Content-Type: application/yaml' \
    --data-binary @git-repos.yaml \
    http://127.0.0.1:8080/api/v1alpha1/git-repositories

curl --fail-with-body \
    -H 'Content-Type: application/yaml' \
    --data-binary @server-inventory-publication.yaml \
    http://127.0.0.1:8080/api/v1alpha1/inventory-publications
