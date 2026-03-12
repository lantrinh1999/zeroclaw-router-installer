# Optional Bridge Design

## Goal

Make installation succeed and produce a working system across supported devices even when `socat` is missing or cannot be installed.

## Decision

- Keep backend selection capability-based: `procd`, `entware`, or `manual`.
- Treat port `8318` as the required internal API endpoint for ZeroClaw.
- Treat port `8317` as an optional public bridge for management/UI compatibility when `socat` is available.

## Backend Behavior

- `procd`
  - keep native `procd` layout and init scripts
  - start `cli-proxy-api` on `8318` unconditionally
  - start `socat` only if the binary exists
- `entware`
  - keep Entware SysV layout
  - configure ZeroClaw to use `8318`
  - try to install `socat`, but continue if unavailable
- `manual`
  - keep generated service scripts
  - always point ZeroClaw to `8318`
  - expose `8317` only when `socat` exists

## Verification Rules

- Installation is successful when:
  - `cli-proxy-api` is listening on `8318`
  - ZeroClaw starts successfully
- Missing `8317` is a warning, not a failure.
- Management UI should resolve to `8317` when the bridge exists, otherwise `8318`.

## Rationale

This removes a fragile dependency on an auxiliary bridge process while preserving the device-native service structure for each supported hardware/runtime combination.
