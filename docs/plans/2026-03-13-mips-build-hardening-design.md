# MIPS Build Hardening

## Goal

Make `sh build.sh mips32r2 zeroclaw` succeed against the current upstream `zeroclaw` source, and fail loudly when the Docker build really fails.

## Problem

- The MIPS pre-build patch in `build.sh` blindly appends `critical-section` to `source/zeroclaw/Cargo.toml`.
- Current upstream `zeroclaw` already contains that dependency and several earlier MIPS portability changes, so the build now fails with a duplicate Cargo key.
- Docker build steps run under plain `sh -c`, so `cargo build` or artifact-copy failures can still end with a misleading `build OK`.
- Temporary MIPS patch files are only restored on the success path.

## Approach

- Keep the fix inside `build.sh`; do not make persistent edits in `source/zeroclaw`.
- Make the `critical-section` insertion conditional so the patch step is safe on both older and newer upstream trees.
- Keep the remaining source rewrites idempotent by only relying on replacements that become no-ops once upstream already matches the desired state.
- Run Docker build commands with fail-fast shell settings so a failed build or missing artifact returns a non-zero exit code.
- Restore `.mips-bak` files and `.cargo/config.toml` after the Docker run regardless of success, then propagate any failure back to the caller.
- Where the output binary name can vary, explicitly check known candidates instead of ending in `|| true`.

## Verification

- `sh -n build.sh`
- `sh build.sh mips32r2 zeroclaw`
- Confirm `binaries/mips32r2/zeroclaw` exists and reports as a MIPS ELF binary.

## Notes

- The current upstream `source/zeroclaw` already includes `portable-atomic`, `critical-section`, and some Prometheus/noop substitutions, so the host-side MIPS patcher must now tolerate partially or fully pre-patched sources.
