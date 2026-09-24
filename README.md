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

- `GitRepository/`: inventory repository URL and branch.
- `Router/`: RouterOS management address; its credential reference must be
  `<PRIMARY_ROUTER_NAME>-credentials`.
- `Server/`: LLDP selectors, management networks, users, and labels.
- `InventoryCaptureGroup/inventory-capture-group-platform.yaml`: platform
  addresses, domains, repositories, networking, and Concourse configuration.
- `InventoryCaptureGroup/inventory-capture-group-servers.yaml`: managed server
  groups and Ansible variables.
- `DNSRecord/`: optional static DNS records.

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
`SSHKeyPair/git-ssh-key` and add it to the configured GitHub inventory
repository as a deploy key with write access. Existing installations can reuse
the key retained in OpenBao.

Provisioning images and Concourse pipelines are optional; configure the deploy
key before enabling pipelines:

```sh
homelabc init --artifacts --pipelines
```

Each published inventory gets a `commands-<group>` pipeline. To run a command
for a group, commit a Bash file named `commands/<group>.sh` to that
publication's repository and branch. For the included `servers` group, commit
`commands/servers.sh` to the `servers-inventory` branch:

```bash
#!/usr/bin/env bash
set -euo pipefail

ansible all -m ping
ansible workstations -m shell -a 'uptime'
```

Only commits changing that file trigger the pipeline. Its complete multiline
contents run in a fresh normal-mode container with the group's live inventory,
Ansible roles, and resolved SSH keys.

The command applies this repository, reads platform variables directly from
Stigmergy, converges the platform, checks `/readyz`, and prints Compose status.
`homelabc run` starts a fresh shell with the selected Ansible roles, live
inventory, and resolved SSH keys inside the container.
