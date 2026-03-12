# Procd Detection And Auto-Start Recovery

## Goal

Fix the OpenWrt/Kwrt install path so systems with real `procd` capability are detected as `procd`, installed with the `procd` backend, and automatically restart services after a reboot. The Docker Kwrt test environment must prove this by surviving `docker restart` with services restored.

## Problem Summary

The current detector incorrectly falls back to `manual` on the Kwrt Docker image even though a `procd` process is started. The false negative comes from overly narrow checks:

- only treating `PID 1 = procd` as authoritative
- only looking for `/sbin/procd`
- downgrading container environments unless the old checks already passed

That causes the installer to choose `installers/manual`, which intentionally does not enable auto-start.

## Decisions

### 1. Detect `procd` by runtime capability, not only by PID 1

`common.sh` should classify the service backend as `procd` when at least one strong `procd` signal is present:

- a running `procd` process can be observed
- a `procd` binary exists in a standard location such as `/sbin/procd` or `/usr/sbin/procd`
- OpenWrt init markers exist together, such as `/etc/rc.common` and `/etc/config`

The detector should still report other init families explicitly when those signals are absent.

### 2. Container runtime is not itself a reason to downgrade

Being inside a container should only force `manual` when no managed backend can be proven. If `procd` is present in a container, the installer should stay on the `procd` path.

### 3. Docker test boot must honor enabled init scripts

The ARM64 OpenWrt/Kwrt Docker entrypoint should simulate a boot sequence closely enough for installer auto-start verification:

- start the fake `procd`
- scan `/etc/rc.d/S*` in order
- invoke each enabled script with `start`

This preserves the meaning of `/etc/init.d/<service> enable` and lets `docker restart` behave like a reboot for installed services.

### 4. Keep the existing installer safety rule

`installers/procd/install.sh` should continue to enable auto-start only after both services start successfully and verification passes. The fix is about choosing the right installer and making the test harness respect enabled services, not about weakening the enable timing.

## Implementation Scope

### Detection updates

Adjust `common.sh` so that:

- `detect_init` recognizes `procd` from a live process and from `/usr/sbin/procd` in addition to the current checks
- container downgrading only applies when no supported managed backend has been detected
- platform exports still show the same user-facing fields, but now report `Installer=procd` for the Kwrt Docker image

### Docker boot simulation

Adjust `docker/entrypoint.sh` so that:

- enabled services in `/etc/rc.d` are started automatically during container startup
- startup is ordered by `S*` symlink names
- logs clearly show which boot-enabled services were started

### Verification coverage

Add a repeatable smoke test flow for the Kwrt image that validates:

1. `setup.sh localhost -p 2222` detects `procd`
2. the installer copies `procd` init scripts and enables them
3. after `docker restart jdc1800pro`, both services come back without manual intervention
4. port `8318` listens after restart, and `8317` also listens when `socat` is available

## Testing Strategy

### Detector validation

Add shell-level checks for the detection flow so the repo can verify:

- `procd` is selected when a live `procd` process exists
- `procd` is selected when `/usr/sbin/procd` exists
- `manual` remains the fallback when no managed backend exists

### Reboot regression

Use the Docker Kwrt environment as the regression harness:

- build and start `docker/devices/jdc1800pro/docker-compose.yml`
- run `setup.sh localhost -p 2222`
- restart the container
- verify process and port health after restart over SSH

If the repo does not already have a non-interactive script for this flow, add one so the scenario is easy to rerun.

## Risks And Guardrails

- Do not auto-start every file in `/etc/init.d`; only honor services already enabled in `/etc/rc.d`.
- Do not use OS branding alone as proof of `procd`; require runtime or filesystem evidence.
- Do not special-case the Docker image in production detection logic; the detector should improve generally for real firmware too.
- Verification output must make failures attributable to one layer: detection, enable symlink creation, boot simulation, or service health.

## Expected Outcome

After the change:

- Kwrt/OpenWrt systems with usable `procd` capability are installed via `installers/procd`
- auto-start is enabled for those systems after install verification succeeds
- the Docker Kwrt test environment proves reboot persistence by restoring services on `docker restart`
