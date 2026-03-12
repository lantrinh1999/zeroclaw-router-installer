# Only-Binary Update Design

## Goal

Add an explicit `only-binary` update mode so setup can refresh the installed binaries and [`configs/cliproxy/static/management.html`](/Users/linhtran/zeroclaw-router-installer/configs/cliproxy/static/management.html) without changing existing config or data on the router.

## Current Problem

- `setup.sh` and `setup.bat` always upload the full `configs` tree.
- All installer entrypoints call `cleanup_existing_installation`, reinstall config files, inject Telegram settings, and rewrite runtime config.
- That makes "update binary only" unsafe because the current flow can overwrite `config.toml`, `config.yaml`, auth files, workspace content, and service scripts.

## Chosen Approach

Introduce an explicit `--only-binary` flag in setup entrypoints and a matching `ONLY_BINARY=1` runtime branch inside each installer.

### Why this approach

- Keeps default install behavior unchanged.
- Avoids heuristic detection of "update mode" from partial state on the device.
- Reuses existing platform detection and service control while isolating the dangerous config-writing steps.
- Lets the update mode fail closed if the device does not already have an installation to update.

## Scope

### In scope

- Add `--only-binary` argument parsing to `setup.sh` and `setup.bat`.
- Upload only the required binary and installer payload in `only-binary` mode, plus the new `management.html`.
- Add installer branches that stop services, replace binaries, replace `management.html`, then restart and verify.
- Keep verification from mutating `/root/.zeroclaw/config.toml` in `only-binary` mode.

### Out of scope

- Reworking the normal full-install flow.
- Updating `config.toml`, `config.yaml`, Telegram values, auth JSON files, workspace files, or persistent runtime data during `only-binary`.
- Replacing init scripts or uninstall behavior.

## Behavior Changes

- `setup.sh --only-binary <ip>` and `setup.bat --only-binary <ip>` perform a narrow update instead of a reinstall.
- The mode must fail if the required installed destinations do not already exist.
- The mode must not call config-install helpers, Telegram prompts/injection, or full teardown logic.
- The only content copied from `configs/` in this mode is `cliproxy/static/management.html`.

## Files Expected To Change

- `setup.sh`
- `setup.bat`
- `common.sh`
- `installers/procd/install.sh`
- `installers/entware/install.sh`
- `installers/manual/install.sh`

## Testing Strategy

- Shell syntax checks on all edited `.sh` files.
- Grep checks that `ONLY_BINARY` branches do not call config-mutating helpers.
- Manual inspection of upload lists in `setup.sh` and `setup.bat` to ensure only `management.html` is sent from `configs/` in update mode.
