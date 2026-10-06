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
FILE_REGISTRY_PASSWORD=replace-me
CLOUDFLARE_API_KEY=replace-me
CLOUDFLARE_EMAIL=replace-me@example.com
ZEROSSL_EMAIL=replace-me@example.com
ZEROSSL_EAB_KID=replace-me
ZEROSSL_EAB_HMAC_KEY=replace-me
```

Do not commit this file.

Before `homelabc init`, run `make api-auth` from the Stigmergy checkout. Append
the generated `.local/api-auth/bootstrap.env` to `~/.homelab-init` (keep mode
0600; do not shell-source it). This supplies the required `STIGMERGY_API_POLICY`
and admin `STIGMERGY_API_TOKEN`; bootstrap installs and mounts the API policy
read-only. Use its separate daemon and runner tokens for those processes, never
the admin token. `STIGMERGY_RUNNER_API_TOKEN` is also required so bootstrap can
publish the runner's scoped API credential to OpenBao for Concourse. Stigmergy's
`create-api-auth --bootstrap-env-source ... --bootstrap-env-output ...` command
can prepare a fresh private combined env-file without printing its contents.

## 2. Site configuration

Review these resources:

- `GitRepository/`: inventory, command, and dedicated `asdf57/iso-data` repository
  URLs and authentication. Create/initialize `iso-data` first and grant the Git
  key write access; the controller creates its input branch, not the GitHub repo.
- `Router/`: RouterOS management address; its credential reference must be
  `<PRIMARY_ROUTER_NAME>-credentials`.
- `Server/`: LLDP selectors, desired installed `operatingSystem`, live-image
  `boot.isoRef`, management networks, users, and labels. Normal boot uses disk
  GRUB; authorized reprovisioning selects its one-shot iPXE entry. Keep
  provisioning disabled until the disk and boot/install tests are approved.
  See Stigmergy's `docs/server-provisioning-rollout.md` for standup and requests.
- `InventoryCaptureGroup/inventory-capture-group-platform.yaml`: platform
  addresses, domains, repositories, networking, and Concourse configuration.
- `InventoryCaptureGroup/inventory-capture-group-servers.yaml`: managed server
  groups and Ansible variables.
- `DNSRecord/`: optional static DNS records.
- `CommandsPipeline/`: reusable capture group, repository, provider, and optional scheduled command template.
- `Command/`: immutable one-shot execution requests targeting an executor;
  scripts are published to UID-owned Git directories.
- `Pipeline/`: explicit persistent operator pipelines. The SSH operator uses
  the existing provider and targets the ssh-managed capture group.
- `ISO/`: image configuration, CA reference, provider, and input repository.
  Its child Pipeline is generated automatically, not uploaded manually.
- `SSHCertificate/`: administrator-managed certificates with automatic renewal;
  the supplied runner certificate uses principal `ansible`, TTL 24h, and renewal
  at 8h remaining. Its public Secret is delivered through Concourse/OpenBao.

The `platform` capture group's `groupVars.all` must define:

```text
cert_authority                 cloudflare_domain
concourse_fqdn                 concourse_internal_url
concourse_target
concourse_team                 concourse_url
concourse_user                 concourse_version
concourse_worker_kernel_modules
copyparty_fqdn
git_webhook_branch             git_webhook_repo
git_stigmergy_web_branch       git_stigmergy_web_repo
ipvlan_gateway                 ipvlan_mode
ipvlan_subnet
macvlan_gateway                macvlan_host_ip
macvlan_mode                   macvlan_subnet
network_driver                 nginx_acme_label
nginx_ipv4                     openbao_acme_label
openbao_api_fqdn
registry_fqdn
stigmergy_fqdn                 stigmergy_ui_fqdn
vikunja_fqdn
vikunja_version
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
inventory, commands, and new ISO-data repositories. Existing installations
can reuse the key retained in OpenBao. An account SSH key supports private
repositories; a repository deploy key only supports the one repository where
it was registered.

Publish the normal command-runner image after configuring the deploy key:

```sh
homelabc init --artifacts
```

The ISO controller creates an owned Pipeline for each ISO resource. Its
versioned public Git inputs contain the image configuration and SSH user-CA
trust bundle, never a management private key or daemon API token. Changes to
those inputs, the builders, or `homelabd` trigger a build. Images include the
fixed `ansible` account reconciler, `homelabd`, `lldpd`, SSH, Python, and the
live-environment marker.

Artifacts and completion manifests use immutable build paths in Copyparty;
there is no mutable `latest.iso` dependency. Downloads are public; uploads
require the `pipeline` account backed by `FILE_REGISTRY_PASSWORD`. PXE follows
the Machine/Server binding and `Server.spec.boot.isoRef`, and only serves a
completed ISO matching the Server's current CA trust.

Upload any other file with curl:

```sh
curl -H "PW: pipeline:$FILE_REGISTRY_PASSWORD" \
  --upload-file ./example.img \
  https://copyparty.ryuugu.dev/example.img
```

Stigmergy uses `CommandsPipeline/commands-pipeline-servers.yaml` as reusable executor settings. `Command/command-servers.yaml` requests one uptime run. Commands share the executor's persistent Concourse pipeline, `run` job and Git branch; each has its own UID-owned script directory, pinned commit and tracked build. A durable executor slot serializes requests so their input revisions cannot race. Deleting one Command keeps the shared pipeline intact. Multiple requests may target the same executor/group.

A Command spec cannot be edited. Use a new resource name for another run; reapplying an existing request is a no-op, but recreating it after deletion runs again. The bootstrap servers example intentionally has no TTL, so repeated bootstrap does not rerun it. Do not put TTL-expiring requests in continuously reapplied desired configuration.

The host-key/user-trust operator is Pipeline/reconcile-ssh-host-keys-ssh-managed,
with a serial operator job and a Concourse time resource (5m). It can also be
triggered manually. Each build reads current InventoryCaptureGroup/ssh-managed
and Server state; it does not create disposable Commands for recurring work.


The command applies this repository, reads platform variables directly from
Stigmergy, converges the platform, checks `/readyz`, and prints Compose status.
`homelabc run` starts a fresh shell with the selected Ansible roles, live
inventory, and resolved SSH keys inside the container.
# SSH management

External LAN web services can be added to `GroupVars/platform.yml` using
`reverse_proxy_hosts` entries with `fqdn` and `upstream`. Their DNS records point
to `nginx_ipv4`, not the appliance. Nginx uses the existing domain certificate,
supports WebSockets/streaming/uploads, and redirects HTTP to HTTPS. HTTPS
upstream certificates are not verified, allowing LAN appliances' self-signed
certificates; this does not authenticate the appliance against a LAN attacker.
PiKVM is configured this way at `pikvm.ryuugu.dev`, upstream `https://10.1.1.51`.

Management uses `SSHKeyPair/ansible-runner` plus its managed `SSHCertificate`.
homelabd has no management authorized-key installation interface.

Apply with an authorized `STIGMERGY_API_TOKEN`. Local `groupVarsRef` files are
rendered into generic `groupVars` by the uploader, not sent as API fields.

See `stigmergy/docs/ssh-management-rollout.md` in the homelab workspace before
applying the manifests. Live images embed the restricted agent token from private
Concourse credentials. ISO and PXE downloads remain public by operator choice:
any downloader can extract and use this agent token. Token rotation requires
rebuilding the images;
the provisioning runner requires a private key and current certificate and
derives strict known_hosts from verified Server public identities in the API.
Opt in before first boot with `homelab.io/ssh-management: enabled`.
The Server controller automatically owns one SSHKeyPair per Server UID. The
operator persists a first-contact TOFU pin before fetching/installing the managed
private host key, verifies a fresh managed-key connection, and reconciles user-CA
trust. First-contact impersonation remains an explicit v1 risk. Subsequent host
key changes fail closed and require deliberate administrator recovery/reset.
Bootstrap supplies the restricted host-key OpenBao AppRole. Existing API policies
must allow the runner GET SSHKeyPair, without rotating its token or granting
Secret reads. See the rollout document for the status-reset and deployment steps.
