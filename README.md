# dGPU power gate — ThinkPad Yoga 460

Truly powers off the unused NVIDIA 940M (`10de:1347`) at boot and after
every suspend/resume, using the laptop's own firmware power resource
`\_SB.PCI0.RP09.NVP3` (decoded from this machine's SSDT11) via the
`acpi_call` module. The vendor's `_OFF` gates the power rails and waits
for hardware confirmation. Typical saving: roughly 1–2 W.

## Install

    git clone git@github.com:allesgeklaut/dgpu-gate.git
    cd dgpu-gate
    sudo bash install-dgpu-gate.sh

Expected last line: `dgpu-gate: dGPU power gated (_STA=0x0)`.
Safe to re-run (idempotent), and works from any location.

## What gets installed

| File in this repo | Installed as | Purpose |
|---|---|---|
| `dgpu-gate.sh` | `/usr/local/sbin/dgpu-gate.sh` | loads `acpi_call`, runs `_ON` → `_OFF` → verifies `_STA`, logs under journal tag `dgpu-gate` |
| `dgpu-gate.service` | `/etc/systemd/system/dgpu-gate.service` | runs the gate once at boot |
| `dgpu-gate-hook` | `/usr/lib/systemd/system-sleep/dgpu-gate` | re-runs the gate after every resume |

Why `_ON` before `_OFF`: after S3 the BIOS re-powers the GPU, but the
firmware's "already off" flag survives in RAM — a plain `_OFF` is ignored
and `_STA` even lies (`0x0` while actually powered). `_ON` re-syncs the
bookkeeping so `_OFF` can gate again.

## Verify

    journalctl -t dgpu-gate -n 5      # last results
    systemctl status dgpu-gate        # boot service state

Manual control (raw ACPI calls, root only):

    # status: 0x0 = gated, 0x1 = powered (can lie after resume until _ON re-sync)
    echo '\_SB.PCI0.RP09.NVP3._STA' | sudo tee /proc/acpi/call; sudo cat /proc/acpi/call
    # power back on (e.g. before ever using a nouveau/nvidia driver):
    echo '\_SB.PCI0.RP09.NVP3._ON' | sudo tee /proc/acpi/call
    # re-gate using the installed script:
    sudo /usr/local/sbin/dgpu-gate.sh

Note: `lspci` still lists the GPU even when gated — config space stays
readable on this machine. Trust `_STA`, not `lspci`.

## Undo / get back

    sudo systemctl disable --now dgpu-gate
    sudo rm /etc/systemd/system/dgpu-gate.service /usr/lib/systemd/system-sleep/dgpu-gate /usr/local/sbin/dgpu-gate.sh
    sudo systemctl daemon-reload
    # optional: power the GPU on right away (a reboot also restores it):
    echo '\_SB.PCI0.RP09.NVP3._ON' | sudo tee /proc/acpi/call

## Dependencies

- `acpi-call-dkms` — on Debian/Ubuntu/Pop!_OS:
  `sudo apt install acpi-call-dkms` (plus matching `linux-headers-*`
  for your kernel). After a kernel update the module rebuilds only if
  matching headers are installed. If it is missing, the gate degrades
  gracefully: the journal shows `acpi_call unavailable` and the GPU
  simply stays powered.

## Caveats

- The ACPI path is specific to this machine's firmware (SSDT11).
  Other laptops — even other Optimus ThinkPads — use different paths;
  dump your own tables (`acpidump`/`iasl`) before adapting.
- Calling firmware methods via `acpi_call` is not risk-free: a
  misbehaving method can freeze the machine (a hard reset recovers).
  Try the raw calls interactively before installing. On this machine
  the vendor methods have been stable.
