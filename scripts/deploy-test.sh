#!/usr/bin/env bash
set -euo pipefail

# Deploy the Quadlet to hero and start the service.
# Stops any existing llama-server service first to free VRAM.
# Usage: deploy-test.sh [user@host]

HOST="${1:-user@hero}"
QUADLET_DIR="~/.config/containers/systemd"
OLD_SERVICE="container-llama-server.service"
SERVICE="llama-server.service"

echo "==> Deploying Quadlet to ${HOST}"

# Stop any running llama services to free VRAM
echo "==> Stopping existing services..."
ssh "${HOST}" "systemctl --user stop ${SERVICE} 2>/dev/null || true"
ssh "${HOST}" "systemctl --user stop ${OLD_SERVICE} 2>/dev/null || true"
sleep 2

# Deploy Quadlet file
echo "==> Copying Quadlet file..."
ssh "${HOST}" "mkdir -p ${QUADLET_DIR}"
scp quadlet/llama-server.container "${HOST}:${QUADLET_DIR}/llama-server.container"
ssh "${HOST}" "systemctl --user daemon-reload"

# Start service
echo "==> Starting ${SERVICE}..."
ssh "${HOST}" "systemctl --user start ${SERVICE}"

# Health check with retries (model loading takes time)
echo "==> Waiting for model to load..."
MAX_RETRIES=20
RETRY_INTERVAL=15
for i in $(seq 1 ${MAX_RETRIES}); do
    if ssh "${HOST}" "curl -sf http://localhost:8080/health" >/dev/null 2>&1; then
        echo "==> Health check passed on attempt ${i}."
        echo ""
        echo "Quadlet service is live on port 8080."
        echo "Verify: ssh ${HOST} systemctl --user status ${SERVICE}"
        exit 0
    fi
    echo "    Attempt ${i}/${MAX_RETRIES} — not ready, retrying in ${RETRY_INTERVAL}s..."
    sleep ${RETRY_INTERVAL}
done

# Health check failed — rollback to old service if available
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
