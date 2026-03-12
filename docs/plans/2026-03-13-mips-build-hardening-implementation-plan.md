# MIPS Build Hardening Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the MIPS ZeroClaw Docker build path resilient to upstream source drift and fail correctly when the build does not produce an artifact.

**Architecture:** Keep the fix localized to `build.sh`. Harden the temporary MIPS patching flow so it is idempotent against newer upstream source trees, and make all Docker build shells fail-fast so host-side status reflects the actual build result.

**Tech Stack:** POSIX shell, Docker, Rust, Go

---

## Chunk 1: MIPS Patch Safety And Failure Propagation

### Task 1: Document the intended build behavior

**Files:**
- Create: `docs/plans/2026-03-13-mips-build-hardening-design.md`
- Create: `docs/plans/2026-03-13-mips-build-hardening-implementation-plan.md`

- [ ] **Step 1: Capture the current failure mode**

Record the observed regression:

- duplicate `critical-section` dependency insertion in `source/zeroclaw/Cargo.toml`
- misleading Docker success output after a failed `cargo build`
- missing cleanup on failed MIPS builds

- [ ] **Step 2: Define the scope boundary**

State that the fix lives in `build.sh` and does not persist edits into the cloned upstream source tree.

### Task 2: Harden `build.sh` MIPS patching and Docker execution

**Files:**
- Modify: `build.sh`

- [ ] **Step 1: Make the `critical-section` dependency insertion conditional**

Only append:

```sh
critical-section = { version = "1", features = ["std"] }
```

when the line is not already present in `source/zeroclaw/Cargo.toml`.

- [ ] **Step 2: Guarantee cleanup after the Docker run**

Restore:

- `Cargo.toml.mips-bak`
- patched Rust source `.mips-bak` files
- `.cargo/config.toml`

even when the Docker container exits non-zero.

- [ ] **Step 3: Make Docker build shells fail-fast**

Change Docker invocations from `sh -c` to `sh -eu -c` so these steps abort immediately:

- dependency/toolchain install failures
- `cargo build` failures
- missing output artifact copies

- [ ] **Step 4: Remove false-success artifact copies**

For Rust `cli-proxy-api` builds, replace trailing `|| true` artifact copy chains with explicit file checks that exit non-zero if neither expected binary name exists.

- [ ] **Step 5: Syntax-check the script**

Run:

```bash
sh -n build.sh
```

Expected: no output, exit code `0`.

### Task 3: Reproduce and verify the original failing command

**Files:**
- Verify: `binaries/mips32r2/zeroclaw`

- [ ] **Step 1: Re-run the original build**

Run:

```bash
sh build.sh mips32r2 zeroclaw
```

Expected:

- no duplicate Cargo key error
- the command exits `0`
- `binaries/mips32r2/zeroclaw` is created

- [ ] **Step 2: Inspect the built artifact**

Run:

```bash
file binaries/mips32r2/zeroclaw
```

Expected: MIPS ELF output for the target architecture.
