#!/bin/bash
# Gate power to the unused NVIDIA 940M dGPU (ThinkPad Yoga 460, 10de:1347).
# Vendor power resource: \_SB.PCI0.RP09.NVP3  (decoded from SSDT11 "SgPch")
# Safe at boot AND after resume:
#   _ON  re-syncs firmware state (no-op when fresh; repairs post-S3 desync)
#   _OFF gates the rails (waits for HW power-gate confirmation)
# Then _STA verifies: 0x0 = gated, 0x1 = powered.
# Always exits 0: a failed gate must never block boot or resume.

CALL=/proc/acpi/call
NVP3='\_SB.PCI0.RP09.NVP3'

if [ "$(id -u)" -ne 0 ]; then
    echo "dgpu-gate: must run as root (writes $CALL)" >&2
    exit 1
fi

modprobe acpi_call 2>/dev/null || true
if [ ! -e "$CALL" ]; then
    logger -t dgpu-gate "acpi_call unavailable (DKMS built for this kernel?) - GPU left powered"
    exit 0
fi

printf '%s' "$NVP3._ON"  > "$CALL"; sleep 0.3
printf '%s' "$NVP3._OFF" > "$CALL"
printf '%s' "$NVP3._STA" > "$CALL"; sleep 0.2
# tr also strips NUL: acpi_call's proc read returns trailing null byte(s)
sta=$(tr -d '\000[:space:]' < "$CALL")

if [ "$sta" = "0x0" ]; then
    logger -t dgpu-gate "dGPU power gated (_STA=$sta)"
else
    logger -t dgpu-gate "dGPU gate FAILED (_STA=$sta) - GPU left powered"
fi
exit 0
