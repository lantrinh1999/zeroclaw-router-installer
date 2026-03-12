# Single-Port 8317 Design

## Goal

Make CLIProxyAPI and ZeroClaw use only port `8317` locally and remotely. Remove the optional `8318` backend/bridge split so setup, runtime config, and operator docs all point to one stable endpoint.

## Current Problem

- Installer writes ZeroClaw provider URLs to `127.0.0.1:8318`.
- Setup probes `8317` and `8318` for the management UI, then prints whichever responds.
- CLIProxyAPI listens on `8318`, while `8317` exists only when `socat` successfully bridges to it.
- This creates mismatches where setup prints `8317` but runtime config still targets `8318`.

## Chosen Approach

Bind CLIProxyAPI directly to `8317` and remove bridge behavior entirely.

### Why this approach

- Matches the user requirement exactly: one local port only.
- Eliminates config drift between printed URLs and runtime behavior.
- Removes `socat` as an optional dependency from installation and startup.
- Simplifies verification and failure handling.

## Scope

### In scope

- Change CLIProxyAPI config default port to `8317`.
- Change ZeroClaw default provider URLs to `127.0.0.1:8317`.
- Update shared verification helpers and service summaries to expect only `8317`.
- Remove `socat` install/start logic from procd, Entware, and manual installers.
- Update setup scripts to verify only `8317`.
- Update targeted smoke checks that still assert `8318`.

### Out of scope

- Broader refactors unrelated to port handling.
- Reworking the UI itself.
- Migrating or rewriting unrelated installer architecture.

## Behavior Changes

- Successful installs must expose CLIProxyAPI and `management.html` on `8317` only.
- ZeroClaw must always use `custom:http://127.0.0.1:8317/v1`.
- If `8317` does not come up, installation/verification should fail or warn against `8317` directly; there is no fallback port.

## Files Expected To Change

- `configs/cliproxy/config.yaml`
- `configs/zeroclaw/config.toml`
- `common.sh`
- `installers/procd/install.sh`
- `installers/procd/init-scripts/cliproxyapi`
- `installers/entware/install.sh`
- `installers/entware/init-scripts/S98cliproxyapi`
- `installers/manual/install.sh`
- `setup.sh`
- `setup.bat`
- Targeted smoke/docs files that still encode `8318`

## Testing Strategy

- Shell syntax check on edited `.sh` files.
- Grep-based regression check to ensure runtime paths no longer reference `127.0.0.1:8318` or `management.html` fallback to `8318`.
- Update and run targeted smoke assertions that previously expected `8318`.
