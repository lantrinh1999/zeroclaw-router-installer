# Installer Naming And Repository Shape

## Goal

Make the repository terminology match the capability-based detection model by:

- keeping binary artifacts under `binaries/<arch>`
- renaming installer strategy directories from `platforms/<name>` to `installers/<name>`
- renaming the exported detector key from `PLATFORM` to `INSTALLER`

The objective is clarity, not new feature scope.

## Problem

The current codebase already separates two concepts:

- `BIN_ARCH`: which binary payload to upload
- `PLATFORM`: which installer strategy directory to run

That model is correct, but the naming is not tight enough:

- `platforms/` sounds like full device or OS platforms
- the directories actually contain installer backends and service integration strategies
- `PLATFORM` suggests a broader runtime identity than what the value means in practice

This makes the repo shape harder to read, especially now that detection can return `manual` for otherwise supported Linux targets.

## Design

### Repository Shape

Keep architecture and installer concerns separate:

- `binaries/aarch64`
- `binaries/mips32r2`
- `installers/procd`
- `installers/entware`
- `installers/manual`

Do not rename `binaries/` in this change. That part is already explicit enough and is referenced widely by scripts and docs.

### Runtime Model

Rename the installer-selection field from `PLATFORM` to `INSTALLER`.

The runtime model becomes:

- `BIN_ARCH`: binary compatibility target
- `INSTALLER`: repository installer strategy
- `SERVICE_BACKEND`: detected service manager capability
- `INSTALL_LAYOUT`: writable filesystem layout

Strategy mapping remains unchanged:

- `procd` backend -> `INSTALLER=procd`
- `entware-sysv` backend -> `INSTALLER=entware`
- writable unmanaged systems -> `INSTALLER=manual`

### Compatibility Scope

This rename is semantic only. It does not expand support.

In particular:

- `installers/procd` still supports only `aarch64`
- `installers/entware` still uses `binaries/$BIN_ARCH`
- `installers/manual` remains the fallback path for writable non-managed systems

### Migration Rules

Update all codepaths that currently rely on `platforms/...` or `PLATFORM`:

- `setup.sh`, `setup.bat`
- `teardown.sh`, `teardown.bat`
- `common.sh` exported variables and info output
- installer scripts under renamed directories
- documentation and project tree examples

Avoid a temporary compatibility shim. The repository is small enough that a full rename is simpler and less ambiguous than dual-path support.

## Risks

- Windows batch scripts currently use older detection logic and need extra care during rename.
- The working tree is already dirty, so edits must stay narrowly scoped and avoid unrelated changes.
- Docs may still describe old assumptions such as `Buildroot => entware`; those references should be corrected while touching the relevant sections.

## Verification

- run `sh -n` on shell scripts touched by the rename
- run `cmd` batch syntax review by inspecting the changed path and variable usage
- grep for stale `platforms/` and `PLATFORM` references
- confirm the repo tree and README examples match the new naming
