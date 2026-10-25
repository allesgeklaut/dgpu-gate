#!/bin/bash
# Minimal persistent dGPU power gating - ThinkPad Yoga 460 (NVIDIA 940M).
# Installs three small files (gate script, boot service, resume hook),
# enables the service, and runs one gating cycle.
# Safe to re-run; works from any location (uses its own folder as source).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install -m 0755 "$SRC/dgpu-gate.sh"      /usr/local/sbin/dgpu-gate.sh
install -m 0755 "$SRC/dgpu-gate-hook"    /usr/lib/systemd/system-sleep/dgpu-gate
install -m 0644 "$SRC/dgpu-gate.service" /etc/systemd/system/dgpu-gate.service

systemctl daemon-reload
systemctl enable dgpu-gate.service

echo "-- one gating cycle now (also exercises the post-resume wake path) --"
/usr/local/sbin/dgpu-gate.sh
journalctl -t dgpu-gate --no-pager -n 2
