#!/usr/bin/env bash
# shellcheck shell=bash disable=SC2029
set -euo pipefail

# Deploy the Quadlet to hero and start the service.
# Stops any existing llama-server service first to free VRAM.
# Usage: deploy-test.sh [user@host]
#
HOST="${1:-user@hero}"
QUADLET_DIR='.config/containers/systemd'
OLD_SERVICE="container-llama-server.service"
SERVICE="llama-server.service"

wait_for_chat_ready() {
    local host="$1"
    local url="$2"
    local max_retries="$3"
    local retry_interval="$4"

    for i in $(seq 1 "${max_retries}"); do
        if ssh "${host}" "curl -sf --max-time 60 '${url}' -H 'Content-Type: application/json' -d '{\"model\":\"Qwen_Qwen3.6-35B-A3B-Q4_K_M.gguf\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with ok.\"}],\"stream\":false,\"max_tokens\":1}'" >/dev/null 2>&1; then
            echo "==> Chat completion readiness passed on attempt ${i}."
            return 0
        fi
        echo "    Attempt ${i}/${max_retries} — chat endpoint not ready, retrying in ${retry_interval}s..."
        sleep "${retry_interval}"
    done

    return 1
}

echo "==> Deploying Quadlet to ${HOST}"

# Stop any running llama services to free VRAM
echo "==> Stopping existing services..."
ssh "${HOST}" "systemctl --user stop ${SERVICE} 2>/dev/null || true"
ssh "${HOST}" "systemctl --user stop ${OLD_SERVICE} 2>/dev/null || true"
sleep 2

# Deploy Quadlet file
echo "==> Copying Quadlet file..."
ssh "${HOST}" "mkdir -p \$HOME/${QUADLET_DIR}"
scp quadlet/llama-server.container "${HOST}:${QUADLET_DIR}/llama-server.container"
ssh "${HOST}" "systemctl --user daemon-reload"

# Start service
echo "==> Starting ${SERVICE}..."
ssh "${HOST}" "systemctl --user start ${SERVICE}"

# Health check with retries (server starts before the model is ready)
echo "==> Waiting for HTTP health..."
MAX_RETRIES=20
RETRY_INTERVAL=15
for i in $(seq 1 ${MAX_RETRIES}); do
    if ssh "${HOST}" "curl -sf http://localhost:8080/health" >/dev/null 2>&1; then
        echo "==> Health check passed on attempt ${i}."
        break
    fi
    echo "    Attempt ${i}/${MAX_RETRIES} — not ready, retrying in ${RETRY_INTERVAL}s..."
    sleep ${RETRY_INTERVAL}
done

if ! ssh "${HOST}" "curl -sf http://localhost:8080/health" >/dev/null 2>&1; then
    echo "==> ERROR: Health check failed after ${MAX_RETRIES} attempts."
    echo "==> Attempting rollback to old service..."
    ssh "${HOST}" "systemctl --user stop ${SERVICE} 2>/dev/null || true"
    ssh "${HOST}" "systemctl --user start ${OLD_SERVICE} 2>/dev/null || true"
    if ssh "${HOST}" "systemctl --user is-active ${OLD_SERVICE}" >/dev/null 2>&1; then
        echo "==> Rollback complete. Old service restored."
    else
        echo "==> WARNING: Old service not available. Manual intervention needed."
    fi
    exit 1
fi

echo "==> Waiting for chat completion readiness..."
if wait_for_chat_ready "${HOST}" 'http://localhost:8080/v1/chat/completions' 20 15; then
    echo ""
    echo "Quadlet service is live on port 8080 and accepting chat completions."
    echo "Verify: ssh ${HOST} systemctl --user status ${SERVICE}"
    exit 0
fi

# Chat readiness failed — rollback to old service if available
echo "==> ERROR: Readiness check failed after ${MAX_RETRIES} attempts."
echo "==> Attempting rollback to old service..."
ssh "${HOST}" "systemctl --user stop ${SERVICE} 2>/dev/null || true"
ssh "${HOST}" "systemctl --user start ${OLD_SERVICE} 2>/dev/null || true"
if ssh "${HOST}" "systemctl --user is-active ${OLD_SERVICE}" >/dev/null 2>&1; then
    echo "==> Rollback complete. Old service restored."
else
    echo "==> WARNING: Old service not available. Manual intervention needed."
fi
exit 1
