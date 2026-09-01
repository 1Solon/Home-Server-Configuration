# Talos configuration

TOPF renders the cluster's Talos machine configurations from `topf.yaml` and
the layered patches in `all/`, `control-plane/`, and `node/`.

## Render

```sh
task gen
```

The repository-pinned wrappers download verified TOPF, SOPS, and Talos CLI
binaries into the user's cache. SOPS still needs access to the AGE private key
for `talsecret.sops.yaml` through its normal environment or key-file locations.

Rendered machine configurations and `talosconfig` are written to
`talos/clusterconfig/` with names matching the TOPF node inventory. They
contain plaintext credentials and are ignored by Git.

## Safety boundaries

- The Talos secrets bundle must remain SOPS-encrypted. The render task refuses
  a missing or plaintext bundle and verifies that TOPF did not change it.
- There is intentionally no repository task that applies, upgrades, resets, or
  bootstraps nodes.
- Inspect and validate rendered configurations before applying them with an
  operationally appropriate workflow.
- Keep Talos on the documented TOPF-supported minor version. Revalidate output
  before changing either TOPF or Talos.
- Binary upgrades are manual because each repository pin is coupled to
  platform-specific checksums. When Renovate changes `talosVersion`, update the
  version and checksums in `scripts/talosctl` in the same change. Update TOPF or
  SOPS only together with all checksums in `scripts/topf`.
- The raw volume named `longhorn-csi` is a legacy partition identity, not an
  active Longhorn dependency. Miroir uses its existing
  `/dev/disk/by-partlabel/r-longhorn-csi` device, so renaming it would risk
  destructive reprovisioning.
