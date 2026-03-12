# Single-Port 8317 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make CLIProxyAPI and ZeroClaw use only port `8317`, removing all `8318` bridge/fallback behavior from installer and setup flows.

**Architecture:** CLIProxyAPI will listen directly on `8317`, and ZeroClaw provider URLs will be rewritten to the same port. Shared helpers and installers will stop treating `8318` as a required backend and will verify only `8317`.

**Tech Stack:** POSIX shell, batch script, static config files, existing installer helpers

---

## Chunk 1: Core Port Defaults

### Task 1: Update default config and helper assumptions

**Files:**
- Modify: `configs/cliproxy/config.yaml`
- Modify: `configs/zeroclaw/config.toml`
- Modify: `common.sh`

- [ ] **Step 1: Write the failing expectation**

Record the new invariant:

```text
CLIProxyAPI default port is 8317.
ZeroClaw provider URLs point to 127.0.0.1:8317.
Shared status output only treats 8317 as the management/API port.
```

- [ ] **Step 2: Implement the minimal config/helper changes**

Update the static config files and shared helper output so `8317` is the only CLIProxyAPI port referenced by default behavior.

- [ ] **Step 3: Run targeted checks**

Run:

```bash
rg -n "127.0.0.1:8318|port: 8318|8318 \\(api\\)|optional bridge" configs common.sh
```

Expected: no remaining runtime references in the edited config/helper paths.

## Chunk 2: Installer Runtime

### Task 2: Remove bridge/fallback logic from installers

**Files:**
- Modify: `installers/procd/install.sh`
- Modify: `installers/procd/init-scripts/cliproxyapi`
- Modify: `installers/entware/install.sh`
- Modify: `installers/entware/init-scripts/S98cliproxyapi`
- Modify: `installers/manual/install.sh`

- [ ] **Step 1: Replace port selection logic**

Make each installer configure ZeroClaw for `8317`, wait for `8317`, and stop installing or starting `socat`.

- [ ] **Step 2: Simplify service startup**

Remove messages and branches that refer to `8318` backend success with optional `8317` bridge success.

- [ ] **Step 3: Run shell syntax checks**

Run:

```bash
sh -n installers/procd/install.sh
sh -n installers/entware/install.sh
sh -n installers/manual/install.sh
sh -n installers/procd/init-scripts/cliproxyapi
sh -n installers/entware/init-scripts/S98cliproxyapi
```

Expected: no syntax errors.

## Chunk 3: Setup And Verification

### Task 3: Align setup scripts and smoke checks with single-port behavior

**Files:**
- Modify: `setup.sh`
- Modify: `setup.bat`
- Modify: `docker/scripts/smoke-jdc1800pro-autostart.sh`
- Modify: docs or readme files only where they directly describe the old fallback behavior

- [ ] **Step 1: Remove probe fallback**

Make setup verification and completion output probe only `8317`.

- [ ] **Step 2: Update automated assertions**

Switch smoke checks that require `8318` to require `8317` instead.

- [ ] **Step 3: Run targeted checks**

Run:

```bash
sh -n setup.sh
rg -n "8318|fallback: :8318|optional bridge" setup.sh setup.bat docker/scripts/smoke-jdc1800pro-autostart.sh README.md
```

Expected: no stale fallback messaging remains in the edited runtime/setup paths.
