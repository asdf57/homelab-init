# Site resources and initialization

- Resources here are executable desired state. Never check destructive
  ProvisioningRun requests into init; create each explicitly through the API/UI.
- Each Server owns its managed SSHKeyPair through controller reconciliation;
  do not manually duplicate key resources per Server or rotate Git SSH keys.
- The management account is always `ansible`; do not add custom management-user
  selection fields. Runtime reconciliation is handled by its installed service
  and timer, not by granting homelabd general root/user-management powers.
- SSH/provisioning pipelines are defined in `Pipeline/pipeline-reconcile-ssh-host-keys.yaml`
  and `Pipeline/pipeline-provision.yaml`, using the `ssh-managed` capture group.
  API-backed Server reservations coordinate mutations across pipelines;
  serial groups do not cross pipelines. Do not add per-attempt pipelines/branches.
- Storage and common provisioning inputs belong in appropriate capture-group
  Ansible group variables. Operators must use Ansible inventory resolution.
- Enabling Server provisioning permits explicit runs/live discovery, not erasure.
  A reviewed replacement creates one immutable ProvisioningRun with the Server
  generation, Server/Machine UIDs and one discovered disk ID. Job triggers poll
  runs and never authorize replacement. Server spec has no disk or counter.
- Beelink was successfully provisioned on request 5; its approved SSD is
  `/dev/disk/by-id/ata-512GB_SSD_MP23B72602251` (serial MP23B72602251). Its USB
  was excluded. This completed request is NOT permission for another replacement.
- Run `homelabc init` through the established configuration, private env file,
  `/srv/homelab` data path and `/homelab-data` runner mount. Preserve existing
  API tokens and Git credentials; never print the env file.
- Before destructive execution, inspect live API state as well as these files.
  After deployment, verify API readiness, resource conditions, Concourse builds
  and artifact URLs; a completed init process alone is not rollout acceptance.
- ISO input data belongs in `asdf57/iso-data`, not the inventory repository.
  Immutable ISO builds and their public kernel/initrd/rootfs artifacts are used
  for the pinned live handoff. Rebuild when desired inputs actually change.
- Provisioning details and tested Concourse pin/unpin commands are documented
  in `ansible-roles/AGENTS.md` and Stigmergy's provisioning rollout guide.
