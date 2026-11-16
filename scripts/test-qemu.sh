#!/usr/bin/env bash
# Sobe a ISO em QEMU + OVMF e grava um screenshot quando o SDDM/Plasma aparecer.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${1:-$ROOT/dist/gaiaos-ivybridge-1.0-amd64.iso}"
OUT_PNG="${2:-$ROOT/docs/img/qemu-uefi-live.png}"
SERIAL="${GAIA_QEMU_SERIAL:-/tmp/gaia-qemu-serial.log}"
MON="/tmp/gaia-qemu.mon"
VARS="/tmp/gaia-ovmf-vars.fd"
CODE="/usr/share/OVMF/OVMF_CODE_4M.fd"

if [ ! -f "$ISO" ]; then
    echo "ISO não encontrada: $ISO" >&2
    exit 1
fi
if [ ! -f "$CODE" ]; then
    echo "OVMF não encontrado em $CODE" >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
$SUDO rm -f "$MON" "$SERIAL"
cp -f /usr/share/OVMF/OVMF_VARS_4M.fd "$VARS"
mkdir -p "$(dirname "$OUT_PNG")"

echo "[qemu] Boot UEFI de $ISO"
$SUDO qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -cpu IvyBridge \
    -m 4096 -smp 2 \
    -drive if=pflash,format=raw,readonly=on,file="$CODE" \
    -drive if=pflash,format=raw,file="$VARS" \
    -cdrom "$ISO" \
    -boot order=d \
    -vga virtio \
    -display vnc=127.0.0.1:7 \
    -serial file:"$SERIAL" \
    -monitor unix:"$MON",server,nowait \
    -netdev user,id=n0 \
    -device virtio-net-pci,netdev=n0 \
    -name gaia-ivybridge \
    >/tmp/gaia-qemu.log 2>&1 &
QPID=$!

cleanup() {
    $SUDO kill "$QPID" >/dev/null 2>&1 || true
    wait "$QPID" 2>/dev/null || true
}
trap cleanup EXIT

echo "[qemu] Aguardando sessão gráfica (até 12 min)..."
ok=0
for _ in $(seq 1 144); do
    if ! kill -0 "$QPID" 2>/dev/null; then
        echo "[qemu] processo encerrou cedo" >&2
        tail -40 /tmp/gaia-qemu.log >&2 || true
        exit 1
    fi
    if [ -f "$SERIAL" ] && grep -Eiq 'sddm|plasma|gaia-ivy|login:' "$SERIAL"; then
        # Dá tempo do greeter desenhar depois da primeira linha do journal.
        sleep 25
        ok=1
        break
    fi
    sleep 5
done

$SUDO python3 - << PY
import socket, time
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect("$MON")
s.settimeout(30)
time.sleep(0.2)
try:
    s.recv(4096)
except Exception:
    pass
cmd = b"screendump /tmp/gaia-qemu.ppm\\n"
s.sendall(cmd)
time.sleep(2)
try:
    print(s.recv(4096).decode("utf-8", "replace"))
except Exception as exc:
    print("monitor:", exc)
s.close()
PY

if [ ! -f /tmp/gaia-qemu.ppm ]; then
    echo "[qemu] screendump não gerou PPM" >&2
    tail -30 "$SERIAL" >&2 || true
    exit 1
fi
convert /tmp/gaia-qemu.ppm "$OUT_PNG"
echo "[qemu] Screenshot: $OUT_PNG"
if [ "$ok" -ne 1 ]; then
    echo "[qemu] O boot não mostrou SDDM/Plasma no serial dentro do prazo." >&2
    exit 1
fi
exit 0
