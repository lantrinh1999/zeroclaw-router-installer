# Capability-Based Init Detection And Manual Fallback

## Goal

Broaden installer coverage from a small set of hardcoded platform assumptions to a capability-based detector that:

- identifies the real init/runtime environment
- chooses the best supported install strategy
- falls back to manual mode when the binaries can run but no managed backend is available

## Detection Model

The detector separates:

- `BIN_ARCH`: binary compatibility target
- `OS_TYPE`: OS family
- `PID1_COMM` and `PID1_EXE`: actual PID 1 identity
- `INIT_TYPE`: detected init family
- `SERVICE_BACKEND`: real service manager capability
- `INSTALL_LAYOUT`: writable install layout
- `EXEC_MODE`: managed service vs manual run
- `INSTALLER`: installer strategy directory in this repo

Detection order:

1. read `uname -m`
2. inspect `/proc/1/comm` and `/proc/1/exe`
3. check init marker files and commands
4. detect writable install roots
5. choose managed installer or manual fallback

## Strategy Mapping

- `procd` -> `installers/procd`
- `entware-sysv` -> `installers/entware`
- everything else with writable layout -> `installers/manual`
- unsupported arch or no writable layout -> fail

Manual mode remains a supported outcome, not an error:

- install binaries and configs
- generate `zeroclaw-service` and `cliproxyapi-service`
- track PID and logs in writable runtime dirs
- do not enable autostart

## Refactor Scope

- move shared detection into `common.sh`
- make `setup.sh` and `teardown.sh` call the shared detector remotely
- add `installers/manual/install.sh`
- add `installers/manual/uninstall.sh`
- extend cleanup and verification helpers to understand manual installs

## Verification

- syntax-check `common.sh`, `setup.sh`, `teardown.sh`, and manual backend scripts with `sh -n`
- smoke-test `print_platform_exports` locally to confirm detector output shape

## Notes

- `systemd`, `openrc`, and generic `sysv` are detected explicitly, but currently map to `manual` because this repo does not yet ship native installers for those backends.
- The previous `linux/buildroot => entware` assumption is intentionally removed from auto-selection.
