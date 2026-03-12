# Procd Detection And Auto-Start Recovery Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Detect real `procd` capability reliably and prove that OpenWrt/Kwrt services auto-start again after reboot in the Docker regression environment.

**Architecture:** Keep installer selection capability-based in `common.sh`, but broaden the `procd` evidence model to include a live process and `/usr/sbin/procd`. Make the ARM64 Docker entrypoint simulate boot by starting only enabled `/etc/rc.d/S*` services, then add a repeatable smoke script that validates detection, install, restart, and service recovery over SSH.

**Tech Stack:** POSIX shell, Docker Compose, OpenWrt-style init scripts, SSH

---

## File Map

- Modify: `common.sh`
  - Harden `detect_init` so `procd` can be recognized from runtime evidence instead of only `PID 1` and `/sbin/procd`.
- Modify: `docker/entrypoint.sh`
  - Simulate boot-time startup for enabled init scripts after `procd` comes up.
- Create: `docker/scripts/smoke-jdc1800pro-autostart.sh`
  - Run a repeatable non-interactive regression flow for detect -> install -> restart -> verify.
- Modify: `docker/README.md`
  - Document the smoke test and explain that enabled services are started on container boot.

## Chunk 1: Detector Hardening

### Task 1: Teach `common.sh` to detect live `procd` capability

**Files:**
- Modify: `common.sh`

- [ ] **Step 1: Add focused helper checks for `procd` evidence**

Add small helpers near the detection functions, for example:

```sh
procd_binary_present() {
    [ -x /sbin/procd ] || [ -x /usr/sbin/procd ]
}

procd_process_running() {
    pidof procd >/dev/null 2>&1
}
```

Fallback safely when `pidof` is unavailable by checking `ps` output instead of failing detection.

- [ ] **Step 2: Update `detect_init` to use the new evidence model**

Make the `procd` branch trigger when any strong `procd` signal is present:

- `PID1_COMM=procd`
- `procd_process_running`
- `procd_binary_present`
- `/etc/rc.common` and `/etc/config` both exist

Keep `systemd`, `openrc`, `entware-sysv`, `busybox-init`, `android-init`, and generic `sysv` branches intact after the `procd` branch.

- [ ] **Step 3: Narrow the container downgrade rule**

Change:

```sh
if [ "$RUNTIME_CONTEXT" = "container" ] && [ "$SERVICE_BACKEND" != "procd" ]; then
    SERVICE_BACKEND="manual"
fi
```

to logic that only forces `manual` when no supported managed backend has already been proven. The result must preserve `procd` inside the Kwrt Docker container.

- [ ] **Step 4: Syntax-check the detector**

Run:

```bash
sh -n common.sh
```

Expected: no output, exit code `0`.

### Task 2: Verify detector output shape before touching Docker boot flow

**Files:**
- Modify: `common.sh`

- [ ] **Step 1: Inspect the detector summary for the Kwrt image**

Run:

```bash
docker compose -f docker/devices/jdc1800pro/docker-compose.yml up -d --build
ssh -p 2222 root@localhost "cd /tmp && rm -rf zc-detect && mkdir zc-detect"
tar cf - common.sh | ssh -p 2222 root@localhost "tar xf - -C /tmp/zc-detect"
ssh -p 2222 root@localhost "cd /tmp/zc-detect && . ./common.sh >/dev/null 2>&1 && detect_platform >/dev/null 2>&1 && print_platform_exports"
```

Expected: exported values include `SERVICE_BACKEND=procd`, `EXEC_MODE=managed-service`, and `INSTALLER=procd`.

- [ ] **Step 2: Check that non-`procd` fallback still works conceptually**

Run:

```bash
rg -n 'SERVICE_BACKEND=\"manual\"|INSTALLER=\"manual\"|EXEC_MODE=\"manual-run\"' common.sh
```

Expected: the manual fallback still exists; only the false-negative `procd` path is being corrected.

- [ ] **Step 3: Stop the Docker fixture before the next chunk**

Run:

```bash
docker compose -f docker/devices/jdc1800pro/docker-compose.yml down
```

Expected: the test container is removed cleanly.

## Chunk 2: Boot Simulation And Reboot Regression

### Task 3: Start only enabled services during Docker boot

**Files:**
- Modify: `docker/entrypoint.sh`

- [ ] **Step 1: Add a small boot-runner function**

Implement a helper that:

- scans `/etc/rc.d/S*`
- skips missing symlinks
- logs the service name being started
- executes each symlink with `start`

Use ordered glob expansion so `S98cliproxyapi` runs before `S99zeroclaw`.

- [ ] **Step 2: Invoke the boot runner after `procd` starts**

Call the helper only after the fake `procd` has been launched and confirmed. Keep SSH startup in place so the container remains reachable for test commands.

- [ ] **Step 3: Syntax-check the entrypoint**

Run:

```bash
sh -n docker/entrypoint.sh
```

Expected: no output, exit code `0`.

### Task 4: Add a repeatable smoke test for detect -> install -> restart -> verify

**Files:**
- Create: `docker/scripts/smoke-jdc1800pro-autostart.sh`

- [ ] **Step 1: Write the fixture bootstrap**

The script should:

- start `docker/devices/jdc1800pro/docker-compose.yml`
- wait for SSH on `localhost:2222`
- stage `common.sh` and assert `INSTALLER=procd`

Use shell assertions such as:

```sh
case "$DETECT_OUTPUT" in
  *"INSTALLER=procd"*) : ;;
  *) echo "expected INSTALLER=procd"; exit 1 ;;
esac
```

- [ ] **Step 2: Install via the `procd` installer without interactive prompts**

Upload:

- `binaries/aarch64`
- `configs`
- `installers/procd`
- `common.sh`

Then run:

```sh
SKIP_CONFIRM=1 TELEGRAM_BOT_TOKEN='test-token' TELEGRAM_USER_ID='123456' sh installers/procd/install.sh
```

The smoke test should not call `setup.sh`, because `setup.sh` currently performs a real Telegram API test on the host side.

- [ ] **Step 3: Verify enablement before restart**

Assert over SSH that these symlinks exist:

- `/etc/rc.d/S98cliproxyapi`
- `/etc/rc.d/S99zeroclaw`

Also check that ports are listening before restart:

```sh
netstat -lnt 2>/dev/null | grep ':8318 '
```

- [ ] **Step 4: Restart and verify recovery**

Run:

```bash
docker restart jdc1800pro
```

Then verify over SSH:

- `pidof cli-proxy-api`
- `pidof zeroclaw`
- `netstat -lnt` shows `:8318`
- `:8317` is listening when `socat` exists

- [ ] **Step 5: Make cleanup reliable**

Wrap the script with `trap` so it always runs:

```bash
docker compose -f docker/devices/jdc1800pro/docker-compose.yml down
```

Expected: the script can be rerun without manual cleanup.

## Chunk 3: Documentation And Final Verification

### Task 5: Document the new boot behavior and regression command

**Files:**
- Modify: `docker/README.md`

- [ ] **Step 1: Update the Kwrt usage section**

Add the smoke-test command and describe what it verifies:

```bash
sh docker/scripts/smoke-jdc1800pro-autostart.sh
```

- [ ] **Step 2: Explain the boot simulation model**

Document that the ARM64 Docker environment now starts only services enabled in `/etc/rc.d`, so `docker restart` acts as a reboot check for installer auto-start.

- [ ] **Step 3: Review the Docker docs for stale wording**

Run:

```bash
rg -n 'setup.sh localhost -p 2222|docker restart|auto-start|/etc/rc.d' docker/README.md
```

Expected: the README explicitly mentions the new reboot verification flow.

### Task 6: Run the end-to-end regression and capture residual risk

**Files:**
- Modify: `docs/plans/2026-03-13-procd-detection-autostart-implementation-plan.md`

- [ ] **Step 1: Run syntax checks**

Run:

```bash
sh -n common.sh
sh -n docker/entrypoint.sh
sh -n docker/scripts/smoke-jdc1800pro-autostart.sh
```

Expected: no output, exit code `0`.

- [ ] **Step 2: Run the smoke test**

Run:

```bash
sh docker/scripts/smoke-jdc1800pro-autostart.sh
```

Expected: detector reports `INSTALLER=procd`, installer finishes successfully, and both services recover after `docker restart`.

- [ ] **Step 3: Summarize remaining risk after validation**

Record any remaining gaps in the execution handoff or commit message, especially:

- the smoke test installs directly with `installers/procd/install.sh` rather than driving `setup.sh`
- the regression proves the Docker Kwrt environment and shared detector path, but not every third-party firmware variant
