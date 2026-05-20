#!/usr/bin/env bash
# shellcheck shell=bash disable=SC2029
set -euo pipefail

# Build and install the Forge proxy container on hero.
# Usage: install-forge-proxy.sh [user@host]
#

HOST="${1:-user@hero}"
QUADLET_DIR='.config/containers/systemd'
BUILD_DIR='.cache/llama-hero/forge-proxy'
IMAGE='localhost/forge-proxy:0.6.0'
SERVICE='forge-proxy.service'

wait_for_chat_ready() {
    local host="$1"
    local url="$2"
    local max_retries="$3"
    local retry_interval="$4"

    for i in $(seq 1 "${max_retries}"); do
        if ssh "${host}" "curl -sf --max-time 60 '${url}' -H 'Content-Type: application/json' -d '{\"model\":\"Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with ok.\"}],\"stream\":false,\"max_tokens\":1}'" >/dev/null 2>&1; then
            echo "==> Forge chat completion readiness passed on attempt ${i}."
            return 0
        fi
        echo "    Attempt ${i}/${max_retries} — Forge chat endpoint not ready, retrying in ${retry_interval}s..."
        sleep "${retry_interval}"
    done

    return 1
}

echo "==> Preparing remote build directory on ${HOST}"
# shellcheck disable=SC2029 # Paths intentionally expand locally for ssh
ssh "${HOST}" "mkdir -p \$HOME/${QUADLET_DIR} \$HOME/${BUILD_DIR}"

echo "==> Copying Forge proxy files"
scp container/forge-proxy.Containerfile "${HOST}:${BUILD_DIR}/Containerfile"
scp quadlet/forge-proxy.container "${HOST}:${QUADLET_DIR}/forge-proxy.container"

echo "==> Building ${IMAGE}"
# shellcheck disable=SC2029 # Image and path intentionally expand locally for ssh
ssh "${HOST}" "podman build -t ${IMAGE} -f \$HOME/${BUILD_DIR}/Containerfile \$HOME/${BUILD_DIR}"

echo "==> Reloading user systemd"
ssh "${HOST}" 'systemctl --user daemon-reload'

echo "==> Starting ${SERVICE}"
# shellcheck disable=SC2029 # Service name intentionally expands locally for ssh
ssh "${HOST}" "systemctl --user restart ${SERVICE}"

echo "==> Waiting for Forge proxy health check"
MAX_RETRIES=12
RETRY_INTERVAL=5
for i in $(seq 1 "${MAX_RETRIES}"); do
    if ssh "${HOST}" 'curl -sf http://localhost:8081/health' >/dev/null 2>&1; then
        echo "==> Forge proxy is healthy on port 8081."
        break
    fi
    echo "    Attempt ${i}/${MAX_RETRIES} — not ready, retrying in ${RETRY_INTERVAL}s..."
    sleep "${RETRY_INTERVAL}"
done

if ! ssh "${HOST}" 'curl -sf http://localhost:8081/health' >/dev/null 2>&1; then
    echo "==> ERROR: Forge proxy health check failed after ${MAX_RETRIES} attempts."
    echo "Inspect: ssh ${HOST} journalctl --user -u ${SERVICE} -n 100 --no-pager"
    exit 1
fi

echo "==> Waiting for Forge chat completion readiness"
if wait_for_chat_ready "${HOST}" 'http://localhost:8081/v1/chat/completions' 20 15; then
    echo "==> Forge proxy is healthy on port 8081 and accepting chat completions."
    echo "Verify: ssh ${HOST} systemctl --user status ${SERVICE}"
    exit 0
fi

echo "==> ERROR: Forge chat completion readiness failed."
echo "Inspect: ssh ${HOST} journalctl --user -u ${SERVICE} -n 100 --no-pager"
exit 1
