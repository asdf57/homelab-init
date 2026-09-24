# Initialize the homelab

## 1. Host and CLI configuration

Install Docker with Compose, Go, and Git. Create the shared data path and
required groups, then log in again:

```sh
sudo groupadd --system homelab 2>/dev/null || true
sudo usermod -aG docker,homelab "$USER"
sudo install -d -o "$USER" -g homelab -m 2775 /srv/homelab
```

Create `~/.homelabc.yaml`:

```yaml
init:
  env_file: ~/.homelab-init
  data_path: /srv/homelab
  mount_path: /homelab-data
  docker_socket: /var/run/docker.sock
  inventory_capture_group: platform
  stigmergy_repo: https://github.com/asdf57/stigmergy.git
  stigmergy_ref: main
  homelab_init_repo: https://github.com/asdf57/homelab-init.git
  homelab_init_ref: main

general:
  image: docker.io/library/homelab:latest
  stigmergy_url: http://127.0.0.1:8080
  inventory_capture_group: servers
  ansible_roles_repo: https://github.com/asdf57/ansible-roles.git
  ansible_roles_ref: main
```

Create `~/.homelab-init`; these are all required inputs:

```sh
touch ~/.homelab-init
chmod 600 ~/.homelab-init
```

```dotenv
PRIMARY_ROUTER_NAME=mikrotik-1
PRIMARY_ROUTER_API_USERNAME=replace-me
PRIMARY_ROUTER_API_PASSWORD=replace-me

GITHUB_WEBHOOK_SECRET=replace-me
CONCOURSE_PASSWORD=replace-me
CLOUDFLARE_API_KEY=replace-me
CLOUDFLARE_EMAIL=replace-me@example.com
ZEROSSL_EMAIL=replace-me@example.com
ZEROSSL_EAB_KID=replace-me
ZEROSSL_EAB_HMAC_KEY=replace-me
```

Do not commit this file.

## 2. Site configuration

Review these resources:

- `GitRepository/`: inventory and command repository URLs and authentication.
- `Router/`: RouterOS management address; its credential reference must be
  `<PRIMARY_ROUTER_NAME>-credentials`.
- `Server/`: LLDP selectors, management networks, users, and labels.
- `InventoryCaptureGroup/inventory-capture-group-platform.yaml`: platform
  addresses, domains, repositories, networking, and Concourse configuration.
- `InventoryCaptureGroup/inventory-capture-group-servers.yaml`: managed server
  groups and Ansible variables.
- `DNSRecord/`: optional static DNS records.
- `CommandsPipeline/`: command file, capture group, repository, and provider.
- `Command/`: multiline command scripts published to each capture group's
  command file.
- `Pipeline/`: declarative Concourse pipelines, including ISO builds.

The `platform` capture group's `groupVars.all` must define:

```text
cert_authority                 cloudflare_domain
concourse_db_ipv4              concourse_fqdn
concourse_ipv4                 concourse_target
concourse_team                 concourse_url
concourse_user                 concourse_version
concourse_worker_kernel_modules
git_webhook_branch             git_webhook_repo
ipvlan_gateway                 ipvlan_mode
ipvlan_subnet
macvlan_gateway                macvlan_host_ip
macvlan_mode                   macvlan_subnet
network_driver                 nginx_acme_label
nginx_ipv4                     openbao_acme_label
openbao_api_fqdn
registry_fqdn                  registry_ipv4
stigmergy_fqdn                 webhook_ipv4
```

DNS is enabled by default and uses `PRIMARY_ROUTER_NAME`. Set
`dns_record_backing_store_ref` to override it, or set
`manage_dns_records: false`.

## 3. Initialize

Build the reusable operator image directly from GitHub, install the CLI, and
initialize the core platform. No source checkout is required on the host:

```sh
docker build -t homelab:latest \
  https://github.com/asdf57/arch-provisioner.git#main
GOPROXY=direct go install github.com/asdf57/homelabc@main
export PATH="$(go env GOPATH)/bin:$PATH"
homelabc init
```

For a new installation, copy `.status.publicKey` from
`SSHKeyPair/git-ssh-key` and add it to the GitHub account that can write the
inventory repository and read the commands repository. Existing installations
can reuse the key retained in OpenBao. An account SSH key supports private
repositories; a repository deploy key only supports the one repository where
it was registered.

Publish the normal command-runner image after configuring the deploy key:

```sh
homelabc init --artifacts
```

Stigmergy also creates the `build-isos` pipeline from
`Pipeline/pipeline-build-isos.yaml`. A change to the ISO builders or
`homelabd` triggers one job that builds Arch and Debian Trixie in parallel.
Every ISO contains `homelabd`, `lldpd`, SSH, Python, the live-environment
marker, and the current `ansible-mgmt` public key. The job publishes immutable
revision tags and updates `latest` at:

```text
registry.ryuugu.dev/homelab/arch-iso
registry.ryuugu.dev/homelab/debian-trixie-iso
```

Pull an ISO with ORAS:

```sh
oras pull registry.ryuugu.dev/homelab/arch-iso:latest
```

Stigmergy creates the `commands-servers` pipeline from
`CommandsPipeline/commands-pipeline-servers.yaml`. Each capture group uses its
own same-named branch. Edit `Command/command-servers.yaml` to change the
multiline script. Stigmergy commits it to `servers.sh` on branch `servers` in
`asdf57/commands` automatically:

```bash
#!/usr/bin/env bash
set -euo pipefail

ansible all --module-name ansible.builtin.command --args 'ps aux'
```

Only changes to that file on that branch trigger it. The complete multiline
file runs in a fresh normal-mode container with the group's live inventory,
current Ansible roles, and resolved SSH keys. Add one `CommandsPipeline` and
one `Command` resource for another capture group.

The command applies this repository, reads platform variables directly from
Stigmergy, converges the platform, checks `/readyz`, and prints Compose status.
`homelabc run` starts a fresh shell with the selected Ansible roles, live
inventory, and resolved SSH keys inside the container.
