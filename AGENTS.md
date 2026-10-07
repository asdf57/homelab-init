# Site resources and initialization

- Resources here are executable desired state, not harmless examples. Review
  enabled provisioning flags and counters before applying or running init.
- Each Server owns its managed SSHKeyPair through controller reconciliation;
  do not manually duplicate key resources per Server or rotate Git SSH keys.
- The management account is always `ansible`; do not add custom management-user
  selection fields. Runtime reconciliation is handled by its installed service
  and timer, not by granting homelabd general root/user-management powers.
- Shared SSH/provisioning operator jobs are defined in
  `Pipeline/pipeline-reconcile-ssh-host-keys.yaml`, use the `ssh-managed` capture
  group and share `server-lifecycle`. Do not add per-attempt pipelines/branches.
- Storage and common provisioning inputs belong in appropriate capture-group
  Ansible group variables. Operators must use Ansible inventory resolution.
- For a reviewed Server replacement, increment its reprovision counter exactly
  once with conditional API writes and promptly update the checked-in Server
  resource to the same counter. Do not let later init roll counters backward or
  replay an old replacement request. Job triggers do not increment counters.
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
