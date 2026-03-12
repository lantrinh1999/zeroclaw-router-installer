# Installer Naming Migration Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename installer strategy terminology from `platforms` / `PLATFORM` to `installers` / `INSTALLER` without changing support scope.

**Architecture:** Keep binary artifacts under `binaries/<arch>` and rename only the installer strategy layer. The detector continues to choose the same strategies (`procd`, `entware`, `manual`), but exports `INSTALLER` and all host scripts upload and execute from `installers/<name>`.

**Tech Stack:** POSIX shell, Windows batch, repository documentation

---

## Chunk 1: Detector And Host Script Naming

### Task 1: Rename exported selector from `PLATFORM` to `INSTALLER`

**Files:**
- Modify: `common.sh`

- [ ] **Step 1: Update the detector variable names**

Change the selector variable and related debug/info output:

- `PLATFORM="unknown"` -> `INSTALLER="unknown"`
- `PLATFORM="procd"` -> `INSTALLER="procd"`
- `PLATFORM="entware"` -> `INSTALLER="entware"`
- `PLATFORM="manual"` -> `INSTALLER="manual"`
- `echo "PLATFORM=$PLATFORM"` -> `echo "INSTALLER=$INSTALLER"`

- [ ] **Step 2: Update detector logs and user-facing summaries**

Run:

```bash
rg -n '\bPLATFORM\b|platform=' common.sh
```

Expected: only comments or prose remain where intentional.

- [ ] **Step 3: Syntax-check shared shell code**

Run:

```bash
sh -n common.sh
```

Expected: no output, exit code `0`.

### Task 2: Update POSIX host scripts to consume `INSTALLER` and `installers/`

**Files:**
- Modify: `setup.sh`
- Modify: `teardown.sh`

- [ ] **Step 1: Rename parsed exports**

Update parsing and display:

- `PLATFORM=$(parse_detect_var PLATFORM)` -> `INSTALLER=$(parse_detect_var INSTALLER)`
- all summary output and warnings use `INSTALLER`

- [ ] **Step 2: Update upload and execution paths**

Change:

- `platforms/$PLATFORM` -> `installers/$INSTALLER`
- `sh platforms/$PLATFORM/install.sh` -> `sh installers/$INSTALLER/install.sh`
- `sh platforms/$PLATFORM/uninstall.sh` -> `sh installers/$INSTALLER/uninstall.sh`

- [ ] **Step 3: Syntax-check host scripts**

Run:

```bash
sh -n setup.sh
sh -n teardown.sh
```

Expected: no output, exit code `0`.

## Chunk 2: Windows Script Alignment

### Task 3: Update `setup.bat` to use the shared detector output model

**Files:**
- Modify: `setup.bat`

- [ ] **Step 1: Replace ad-hoc detection with remote `common.sh` detector flow**

Mirror the POSIX flow:

- stage `common.sh`
- run `detect_platform` and `print_platform_exports`
- parse `ARCH`, `BIN_ARCH`, `INSTALLER`, `RESULT`

- [ ] **Step 2: Rename path references**

Change:

- `platforms\%PLATFORM%` -> `installers\%INSTALLER%`
- `sh platforms/%PLATFORM%/install.sh` -> `sh installers/%INSTALLER%/install.sh`

- [ ] **Step 3: Review batch syntax and stale terms**

Run:

```bash
rg -n 'PLATFORM|platforms[\\\\/]' setup.bat
```

Expected: no stale path usage except intentionally preserved prose.

### Task 4: Update `teardown.bat` to use the same installer terminology

**Files:**
- Modify: `teardown.bat`

- [ ] **Step 1: Replace legacy detection with shared detector output**

Parse at least:

- `INSTALLER`
- `BIN_ARCH`
- `ARCH`

- [ ] **Step 2: Rename upload and execution paths**

Change:

- `platforms\%PLATFORM%\uninstall.sh` -> `installers\%INSTALLER%\uninstall.sh`
- `sh platforms/%PLATFORM%/uninstall.sh` -> `sh installers/%INSTALLER%/uninstall.sh`

- [ ] **Step 3: Review batch syntax and stale terms**

Run:

```bash
rg -n 'PLATFORM|platforms[\\\\/]' teardown.bat
```

Expected: no stale path usage except intentionally preserved prose.

## Chunk 3: Repository Layout And Installer Scripts

### Task 5: Rename installer directories on disk

**Files:**
- Move: `platforms/procd` -> `installers/procd`
- Move: `platforms/entware` -> `installers/entware`
- Move: `platforms/manual` -> `installers/manual`

- [ ] **Step 1: Move directories**

Run:

```bash
mv platforms/procd installers/procd
mv platforms/entware installers/entware
mv platforms/manual installers/manual
```

Expected: installer scripts exist at the new paths.

- [ ] **Step 2: Verify repo tree**

Run:

```bash
rg --files installers binaries | sort
```

Expected: `installers/{procd,entware,manual}` and existing `binaries/*` paths are present.

### Task 6: Update installer scripts for internal naming consistency

**Files:**
- Modify: `installers/procd/install.sh`
- Modify: `installers/procd/uninstall.sh`
- Modify: `installers/entware/install.sh`
- Modify: `installers/entware/uninstall.sh`
- Modify: `installers/manual/install.sh`
- Modify: `installers/manual/uninstall.sh`

- [ ] **Step 1: Rename forced selector variable**

Change installer-local overrides:

- `PLATFORM="procd"` -> `INSTALLER="procd"`
- `PLATFORM="entware"` -> `INSTALLER="entware"`
- `PLATFORM="manual"` -> `INSTALLER="manual"`

- [ ] **Step 2: Update any conditionals that branch on the selector**

Run:

```bash
rg -n '\bPLATFORM\b|platforms/' installers
```

Expected: only comments or intentionally preserved prose remain.

- [ ] **Step 3: Syntax-check installer scripts**

Run:

```bash
find installers -type f -name '*.sh' -exec sh -n {} +
```

Expected: no output, exit code `0`.

## Chunk 4: Documentation And Final Verification

### Task 7: Align README and design docs with the new terminology

**Files:**
- Modify: `README.md`
- Modify: `docs/plans/2026-03-13-capability-detection-design.md`
- Modify: `docs/plans/2026-03-13-optional-bridge-design.md`

- [ ] **Step 1: Update path examples and tree output**

Change:

- `platforms/` -> `installers/`
- mention `installers/manual`
- update command examples that run `install.sh` directly

- [ ] **Step 2: Update terminology in detection docs**

Prefer:

- `INSTALLER`: installer strategy directory in this repo

- [ ] **Step 3: Review stale references**

Run:

```bash
rg -n 'platforms/|PLATFORM\b' README.md docs/plans
```

Expected: no stale references except within historical discussion that is still accurate.

### Task 8: Perform end-to-end grep and summarize residual risk

**Files:**
- Modify: `docs/plans/2026-03-13-installer-naming-implementation-plan.md`

- [ ] **Step 1: Check global stale references**

Run:

```bash
rg -n 'platforms/|PLATFORM\b' .
```

Expected: no stale runtime references outside intentionally historical docs.

- [ ] **Step 2: Check new terminology coverage**

Run:

```bash
rg -n 'INSTALLER|installers/' common.sh setup.sh teardown.sh setup.bat teardown.bat installers README.md docs/plans
```

Expected: detector, scripts, and docs all use the new terminology consistently.

- [ ] **Step 3: Record any remaining known limitations**

Document if anything remains intentionally unchanged, such as:

- `binaries/mips32r2` naming being broader than the concrete `mipsle softfloat` target
- unchanged support scope for `installers/procd`
