#!/bin/sh
# =======================================================
# ZeroClaw + CLIProxyAPI Cross-Compile Build Script
# =======================================================
# Build binary cho aarch64 (ARM64).
#
# Usage:
#   sh build.sh                              # Build cả 2 (zeroclaw + cliproxy)
#   sh build.sh zeroclaw                     # Build chỉ zeroclaw
#   sh build.sh cliproxy                     # Build chỉ CLIProxyAPI
#
# Requirements:
#   - Docker (khuyến nghị) hoặc Rust toolchain + cross-compile targets
#   - Source code tự clone từ GitHub nếu chưa có

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/binaries/aarch64"
SOURCE_DIR="$SCRIPT_DIR/source"

# -- GitHub Repos ------------------------------------
ZEROCLAW_REPO="https://github.com/zeroclaw-labs/zeroclaw.git"
CLIPROXY_REPO="https://github.com/router-for-me/CLIProxyAPI.git"

# -- Source paths (trong repo, gitignored) -----------
ZEROCLAW_SRC="$SOURCE_DIR/zeroclaw"
CLIPROXY_SRC="$SOURCE_DIR/CLIProxyAPI"

# Cargo profile for release builds
CARGO_PROFILE="${CARGO_PROFILE:-release}"

# Target
RUST_TARGET="aarch64-unknown-linux-musl"

# Component filter (zeroclaw|cliproxy|all)
BUILD_COMPONENT="all"

# -- Colors ------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# =======================================================
# Source Code Management
# =======================================================

ensure_source() {
    mkdir -p "$SOURCE_DIR"
    echo ""
}

# =======================================================
# Build Methods
# =======================================================

# -- Docker Build (recommended) ----------------------
build_docker() {
    info "Building aarch64 via Docker (target: $RUST_TARGET)..."
    [ "$BUILD_COMPONENT" != "all" ] && info "  Component filter: $BUILD_COMPONENT"
    mkdir -p "$OUTPUT_DIR"

    # -- Build ZeroClaw (Rust) --
    if [ "$BUILD_COMPONENT" != "cliproxy" ] && [ -f "$ZEROCLAW_SRC/Cargo.toml" ]; then
        info "Building ZeroClaw (aarch64)..."
        docker run --rm \
            -v "$ZEROCLAW_SRC:/app" \
            -v "$OUTPUT_DIR:/output" \
            -w /app \
            messense/rust-musl-cross:aarch64-musl \
            sh -eu -c "
                cargo build --profile $CARGO_PROFILE --target $RUST_TARGET --locked 2>&1
                cp target/$RUST_TARGET/$CARGO_PROFILE/zeroclaw /output/zeroclaw
                aarch64-unknown-linux-musl-strip /output/zeroclaw 2>/dev/null || true
                echo 'ZeroClaw build OK'
            "
        info "  -> $OUTPUT_DIR/zeroclaw ($(du -h "$OUTPUT_DIR/zeroclaw" 2>/dev/null | cut -f1))"
    elif [ "$BUILD_COMPONENT" != "cliproxy" ]; then
        warn "ZeroClaw source not found at $ZEROCLAW_SRC"
    fi

    # -- Build CLIProxyAPI --
    if [ "$BUILD_COMPONENT" != "zeroclaw" ] && [ -f "$CLIPROXY_SRC/go.mod" ]; then
        info "Building CLIProxyAPI (aarch64) -- Go..."
        docker run --rm \
            -v "$CLIPROXY_SRC:/app" \
            -v "$OUTPUT_DIR:/output" \
            -w /app \
            --platform linux/amd64 \
            golang:1.24-alpine \
            sh -eu -c "
                GOTOOLCHAIN=auto CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
                    go build -ldflags='-s -w' -o /output/cli-proxy-api ./cmd/server 2>&1
                echo 'CLIProxyAPI build OK'
            "
        info "  -> $OUTPUT_DIR/cli-proxy-api ($(du -h "$OUTPUT_DIR/cli-proxy-api" 2>/dev/null | cut -f1))"
    elif [ "$BUILD_COMPONENT" != "zeroclaw" ] && [ -f "$CLIPROXY_SRC/Cargo.toml" ]; then
        info "Building CLIProxyAPI (aarch64) -- Rust..."
        docker run --rm \
            -v "$CLIPROXY_SRC:/app" \
            -v "$OUTPUT_DIR:/output" \
            -w /app \
            messense/rust-musl-cross:aarch64-musl \
            sh -eu -c "
                cargo build --profile $CARGO_PROFILE --target $RUST_TARGET --locked 2>&1
                if [ -f target/$RUST_TARGET/$CARGO_PROFILE/cli-proxy-api ]; then
                    cp target/$RUST_TARGET/$CARGO_PROFILE/cli-proxy-api /output/cli-proxy-api
                elif [ -f target/$RUST_TARGET/$CARGO_PROFILE/cliproxyapi ]; then
                    cp target/$RUST_TARGET/$CARGO_PROFILE/cliproxyapi /output/cli-proxy-api
                else
                    echo 'CLIProxyAPI artifact not found after cargo build' >&2
                    exit 1
                fi
                aarch64-unknown-linux-musl-strip /output/cli-proxy-api 2>/dev/null || true
                echo 'CLIProxyAPI build OK'
            "
        info "  -> $OUTPUT_DIR/cli-proxy-api ($(du -h "$OUTPUT_DIR/cli-proxy-api" 2>/dev/null | cut -f1))"
    elif [ "$BUILD_COMPONENT" != "zeroclaw" ]; then
        warn "CLIProxyAPI source not found at $CLIPROXY_SRC"
    fi
}

# -- Native Build (fallback) -------------------------
build_native() {
    info "Building aarch64 natively (target: $RUST_TARGET)..."
    [ "$BUILD_COMPONENT" != "all" ] && info "  Component filter: $BUILD_COMPONENT"
    mkdir -p "$OUTPUT_DIR"

    # ZeroClaw (Rust)
    if [ "$BUILD_COMPONENT" != "cliproxy" ] && [ -f "$ZEROCLAW_SRC/Cargo.toml" ]; then
        if ! command -v rustup >/dev/null 2>&1; then
            error "rustup not found. Install Rust: https://rustup.rs"
        else
            rustup target add "$RUST_TARGET" 2>/dev/null || true
            info "Building ZeroClaw (aarch64)..."
            cd "$ZEROCLAW_SRC"
            cargo build --profile "$CARGO_PROFILE" --target "$RUST_TARGET" --locked
            cp "target/$RUST_TARGET/$CARGO_PROFILE/zeroclaw" "$OUTPUT_DIR/zeroclaw"
            strip "$OUTPUT_DIR/zeroclaw" 2>/dev/null || true
            info "  -> $OUTPUT_DIR/zeroclaw ($(du -h "$OUTPUT_DIR/zeroclaw" | cut -f1))"
        fi
    fi

    # CLIProxyAPI (Go)
    if [ "$BUILD_COMPONENT" != "zeroclaw" ] && [ -f "$CLIPROXY_SRC/go.mod" ]; then
        if ! command -v go >/dev/null 2>&1; then
            error "Go not found. Install Go: https://go.dev/dl/"
        else
            info "Building CLIProxyAPI (aarch64) -- Go..."
            cd "$CLIPROXY_SRC"
            CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
                go build -ldflags="-s -w" -o "$OUTPUT_DIR/cli-proxy-api" .
            info "  -> $OUTPUT_DIR/cli-proxy-api ($(du -h "$OUTPUT_DIR/cli-proxy-api" | cut -f1))"
        fi
    fi

    cd "$SCRIPT_DIR"
}

# =======================================================
# Build Orchestration
# =======================================================

do_build() {
    echo ""
    printf "${BOLD}Building: aarch64${NC}\n"
    printf "  Target:   %s\n" "$RUST_TARGET"
    printf "  Desc:     ARM64 (OpenWrt routers, Raspberry Pi 4+)\n"
    printf "  Output:   %s/\n" "$OUTPUT_DIR"
    echo ""

    if command -v docker >/dev/null 2>&1; then
        build_docker
    else
        warn "Docker not found. Using native cross-compile."
        build_native
    fi

    # -- Copy configs --
    CONFIGS_SRC="$SCRIPT_DIR/configs"
    if [ -d "$CONFIGS_SRC" ]; then
        info "Copying configs to $OUTPUT_DIR/configs/..."
        mkdir -p "$OUTPUT_DIR/configs/cliproxy/static"
        cp "$CONFIGS_SRC/cliproxy/config.yaml" "$OUTPUT_DIR/configs/cliproxy/" 2>/dev/null || true
        cp -r "$CONFIGS_SRC/cliproxy/auth" "$OUTPUT_DIR/configs/cliproxy/" 2>/dev/null || true
        if [ -f "$CONFIGS_SRC/cliproxy/static/management.html" ]; then
            cp "$CONFIGS_SRC/cliproxy/static/management.html" "$OUTPUT_DIR/configs/cliproxy/static/"
            info "  management.html copied ($(du -h "$OUTPUT_DIR/configs/cliproxy/static/management.html" | cut -f1))"
        else
            warn "  management.html not found in $CONFIGS_SRC/cliproxy/static/"
        fi
        if [ -d "$CONFIGS_SRC/zeroclaw" ]; then
            cp -r "$CONFIGS_SRC/zeroclaw" "$OUTPUT_DIR/configs/" 2>/dev/null || true
        fi
    else
        warn "Configs directory not found at $CONFIGS_SRC"
    fi

    # Verify output
    echo ""
    if [ -f "$OUTPUT_DIR/zeroclaw" ]; then
        info " zeroclaw: $(du -h "$OUTPUT_DIR/zeroclaw" | cut -f1)"
        file "$OUTPUT_DIR/zeroclaw" 2>/dev/null || true
    else
        warn " zeroclaw: NOT BUILT"
    fi
    if [ -f "$OUTPUT_DIR/cli-proxy-api" ]; then
        info " cli-proxy-api: $(du -h "$OUTPUT_DIR/cli-proxy-api" | cut -f1)"
        file "$OUTPUT_DIR/cli-proxy-api" 2>/dev/null || true
    else
        warn " cli-proxy-api: NOT BUILT"
    fi
    if [ -f "$OUTPUT_DIR/configs/cliproxy/static/management.html" ]; then
        info " management.html: $(du -h "$OUTPUT_DIR/configs/cliproxy/static/management.html" | cut -f1)"
    else
        warn " management.html: NOT COPIED"
    fi
    echo ""
}

# =======================================================
# Main
# =======================================================

# Parse component filter from CLI arg
case "${1:-}" in
    zeroclaw)  BUILD_COMPONENT="zeroclaw" ;;
    cliproxy)  BUILD_COMPONENT="cliproxy" ;;
    all|"")    BUILD_COMPONENT="all" ;;
    --help|-h)
        echo "Usage: sh build.sh [component]"
        echo ""
        echo "Architecture: aarch64 (ARM64 -- OpenWrt routers, RPi 4+)"
        echo ""
        echo "Components (optional, default: all):"
        echo "  zeroclaw  Build only ZeroClaw"
        echo "  cliproxy  Build only CLIProxyAPI"
        echo "  all       Build both (default)"
        echo ""
        echo "Examples:"
        echo "  sh build.sh                # Build cả 2"
        echo "  sh build.sh zeroclaw       # Chỉ build ZeroClaw"
        echo "  sh build.sh cliproxy       # Chỉ build CLIProxyAPI"
        echo ""
        echo "Source code is stored in source/ (auto-cloned, gitignored):"
        echo "  ZeroClaw:    $ZEROCLAW_REPO"
        echo "  CLIProxyAPI: $CLIPROXY_REPO"
        echo ""
        echo "Environment variables:"
        echo "  CARGO_PROFILE  Cargo build profile (default: release)"
        exit 0
        ;;
    *)
        error "Unknown argument: $1"
        echo "Run 'sh build.sh --help' for usage"
        exit 1
        ;;
esac

ensure_source
do_build
