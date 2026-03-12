#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/docker/devices/jdc1800pro/docker-compose.yml"
REMOTE_DIR="/tmp/zeroclaw-smoke"
ROUTER_HOST="localhost"
ROUTER_PORT="2222"
ROUTER_USER="root"
ROUTER_PASSWORD="root"
CONTAINER_NAME="jdc1800pro"
SSH_OPTS="-p $ROUTER_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5"

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "[ERROR] Missing required command: $1" >&2
        exit 1
    }
}

ssh_run() {
    sshpass -p "$ROUTER_PASSWORD" ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" "$@"
}

wait_for_ssh() {
    _ATTEMPT=0
    while [ "$_ATTEMPT" -lt 30 ]; do
        if ssh_run "echo ok" >/dev/null 2>&1; then
            return 0
        fi
        _ATTEMPT=$((_ATTEMPT + 1))
        sleep 1
    done
    return 1
}

wait_for_remote_command() {
    _CMD="$1"
    _ATTEMPT=0
    while [ "$_ATTEMPT" -lt 30 ]; do
        if ssh_run "$_CMD" >/dev/null 2>&1; then
            return 0
        fi
        _ATTEMPT=$((_ATTEMPT + 1))
        sleep 1
    done
    return 1
}

dump_remote_diagnostics() {
    if ! ssh_run "echo ok" >/dev/null 2>&1; then
        echo "[WARN] SSH is unavailable; skipping remote diagnostics" >&2
        return 0
    fi

    echo "[INFO] Remote process list:" >&2
    ssh_run "ps" >&2 || true
    echo "[INFO] Remote listening ports:" >&2
    ssh_run "netstat -lnt 2>/dev/null" >&2 || true
    echo "[INFO] Remote install log:" >&2
    ssh_run "cat /tmp/zeroclaw-install.log 2>/dev/null" >&2 || true
}

fail() {
    echo "[ERROR] $1" >&2
    dump_remote_diagnostics
    exit 1
}

cleanup() {
    docker compose -f "$COMPOSE_FILE" down >/dev/null 2>&1 || true
}

trap cleanup EXIT INT TERM

require_cmd docker
require_cmd ssh
require_cmd sshpass
require_cmd tar

echo "[1/6] Starting Docker fixture..."
docker compose -f "$COMPOSE_FILE" up -d --build >/dev/null

echo "[2/6] Waiting for SSH..."
wait_for_ssh || fail "SSH did not become ready on localhost:$ROUTER_PORT"

echo "[3/6] Uploading staged installer files..."
ssh_run "rm -rf '$REMOTE_DIR' && mkdir -p '$REMOTE_DIR'" || fail "Failed to prepare remote staging directory"
tar cf - -C "$ROOT_DIR" common.sh binaries/aarch64 configs installers/procd \
    | sshpass -p "$ROUTER_PASSWORD" ssh $SSH_OPTS "$ROUTER_USER@$ROUTER_HOST" "tar xf - -C '$REMOTE_DIR'" \
    || fail "Failed to upload staged installer files"

echo "[4/6] Validating detector output..."
DETECT_OUTPUT=$(ssh_run "cd '$REMOTE_DIR' && . ./common.sh >/dev/null 2>&1 && detect_platform >/dev/null 2>&1 && print_platform_exports") \
    || fail "Failed to run detector in the router fixture"
printf '%s\n' "$DETECT_OUTPUT"
printf '%s\n' "$DETECT_OUTPUT" | grep '^SERVICE_BACKEND=procd$' >/dev/null || fail "Expected SERVICE_BACKEND=procd"
printf '%s\n' "$DETECT_OUTPUT" | grep '^EXEC_MODE=managed-service$' >/dev/null || fail "Expected EXEC_MODE=managed-service"
printf '%s\n' "$DETECT_OUTPUT" | grep '^INSTALLER=procd$' >/dev/null || fail "Expected INSTALLER=procd"

echo "[5/6] Installing procd backend..."
ssh_run "cd '$REMOTE_DIR' && SKIP_CONFIRM=1 TELEGRAM_BOT_TOKEN='test-token' TELEGRAM_USER_ID='123456' sh installers/procd/install.sh" \
    || fail "The procd installer failed"

echo "[INFO] Verifying enablement before restart..."
ssh_run "[ -L /etc/rc.d/S98cliproxyapi ] && [ -L /etc/rc.d/S99zeroclaw ]" \
    || fail "Expected enabled service symlinks in /etc/rc.d"
ssh_run "netstat -lnt 2>/dev/null | grep ':8317 '" >/dev/null 2>&1 \
    || fail "Expected port 8317 to be listening before restart"

echo "[6/6] Restarting container and verifying auto-start..."
docker restart "$CONTAINER_NAME" >/dev/null || fail "docker restart failed"
wait_for_ssh || fail "SSH did not recover after docker restart"
wait_for_remote_command "pidof cli-proxy-api >/dev/null 2>&1" \
    || fail "cli-proxy-api did not restart automatically"
wait_for_remote_command "pidof zeroclaw >/dev/null 2>&1" \
    || fail "zeroclaw did not restart automatically"
wait_for_remote_command "netstat -lnt 2>/dev/null | grep ':8317 '" \
    || fail "Expected port 8317 to be listening after restart"

echo "[OK] Kwrt procd detection and auto-start smoke test passed."
