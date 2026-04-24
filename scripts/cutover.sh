#!/usr/bin/env bash
set -euo pipefail

# Archive the old podman-generate-systemd unit after Quadlet migration.
# Run this after verifying the Quadlet service works.
# Usage: cutover.sh [user@host]

HOST="${1:-user@hero}"
OLD_UNIT_DIR="~/.config/systemd/user"
OLD_SERVICE="container-llama-server.service"

echo "==> Archiving old service on ${HOST}"

ssh "${HOST}" "systemctl --user disable ${OLD_SERVICE} 2>/dev/null || true"
ssh "${HOST}" "mv ${OLD_UNIT_DIR}/${OLD_SERVICE} ${OLD_UNIT_DIR}/${OLD_SERVICE}.pre-quadlet 2>/dev/null || true"
ssh "${HOST}" "systemctl --user daemon-reload"

echo "==> Done. Old service archived as ${OLD_SERVICE}.pre-quadlet"
echo "==> Keep for 48h as rollback safety net, then delete."
