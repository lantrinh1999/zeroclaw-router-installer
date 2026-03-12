# Only-Binary Update Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe `only-binary` update mode that refreshes binaries and `management.html` without changing existing router config or data.

**Architecture:** Setup entrypoints will parse `--only-binary`, upload a reduced payload, and pass `ONLY_BINARY=1` to the platform installer. Each installer will branch early into a narrow update path that replaces installed executables and `management.html`, restarts services, and skips config-writing helpers.

**Tech Stack:** POSIX shell, Windows batch, existing installer helper library

---

## Chunk 1: Setup Entry Points

### Task 1: Add explicit only-binary mode to local setup scripts

**Files:**
- Modify: `setup.sh`
- Modify: `setup.bat`

- [ ] **Step 1: Extend argument parsing**

Accept `--only-binary` while preserving existing IP and `-p` parsing.

- [ ] **Step 2: Skip Telegram collection in update mode**

When `--only-binary` is set, bypass local Telegram prompts/tests entirely and do not pass `TELEGRAM_BOT_TOKEN` or `TELEGRAM_USER_ID` to the remote installer.

- [ ] **Step 3: Reduce the upload payload**

In `only-binary` mode, upload:

```text
binaries/$BIN_ARCH
common.sh
installers/$INSTALLER
configs/cliproxy/static/management.html
```

and avoid uploading the rest of `configs/`.

- [ ] **Step 4: Pass mode to the remote installer**

Run the remote installer with `ONLY_BINARY=1`, and keep verify steps read-only in this mode by skipping the local `sed -i` provider rewrite path.

## Chunk 2: Shared Helper Support

### Task 2: Add a safe update helper for existing installs

**Files:**
- Modify: `common.sh`

- [ ] **Step 1: Add a narrow update helper**

Create a helper that validates the installed destinations exist, stops services, replaces the two binaries, refreshes `management.html`, and restarts runtime.

- [ ] **Step 2: Preserve existing service wiring**

Do not reuse helpers that disable autostart, delete init scripts, or remove installed payloads. The `only-binary` path must restart through the already-installed procd, Entware, or manual service scripts and preserve existing init/autostart state.

- [ ] **Step 3: Keep config and data untouched**

Do not call:

```text
cleanup_existing_installation
ask_telegram_config
install_zeroclaw_config
install_cliproxy_config
inject_telegram_config
set_zeroclaw_provider_port
```

from the `only-binary` flow.

- [ ] **Step 4: Run targeted grep checks**

Run:

```bash
rg -n "cleanup_existing_installation|ask_telegram_config|install_zeroclaw_config|install_cliproxy_config|inject_telegram_config|set_zeroclaw_provider_port" installers/procd/install.sh installers/entware/install.sh installers/manual/install.sh
```

Expected: the calls remain in full-install flow only, not in `ONLY_BINARY` branches.

Run:

```bash
rg -n "disable 2>/dev/null|rm -f /etc/init.d|rm -f /opt/etc/init.d|rm -rf /usr/local/lib/zeroclaw|rm -rf /usr/lib/zeroclaw" common.sh
```

Expected: destructive service teardown helpers exist only in full reinstall paths, not in the new update helper.

## Chunk 3: Platform Installers

### Task 3: Branch each installer into full install vs only-binary update

**Files:**
- Modify: `installers/procd/install.sh`
- Modify: `installers/entware/install.sh`
- Modify: `installers/manual/install.sh`

- [ ] **Step 1: Add early `ONLY_BINARY` branch**

After platform detection and binary prechecks, route into the narrow update helper and exit on success.

- [ ] **Step 2: Preserve existing full-install behavior**

Keep the current Telegram/config/init-script flow unchanged when `ONLY_BINARY` is not set.

- [ ] **Step 3: Run shell syntax checks**

Run:

```bash
sh -n common.sh
sh -n setup.sh
sh -n installers/procd/install.sh
sh -n installers/entware/install.sh
sh -n installers/manual/install.sh
```

Expected: no syntax errors.

- [ ] **Step 4: Verify setup verify path is non-mutating in update mode**

Run:

```bash
rg -n "provider synced|sed -i .*127.0.0.1:8317" setup.sh setup.bat
```

Expected: the config rewrite remains only in the full-install verify path and is skipped when `--only-binary` is active.
