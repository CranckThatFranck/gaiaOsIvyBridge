#!/usr/bin/env bash
# Checagens que rodam no repositório, sem a ISO.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1] Sintaxe dos scripts"
while IFS= read -r -d '' f; do
    bash -n "$f"
done < <(find bin scripts live-build -type f \( -name '*.sh' -o -name '*.chroot' -o -name 'config' \) -print0)
bash -n tests/verify-security.sh
bash -n tests/verify-repo.sh

echo "[2] Python e C"
python3 -m py_compile profile_hardware.py guardian/ui/gaia-guardian-ui guardian/src/gaia-gemini-advisor
gcc -O2 -Wall -Wextra -std=c11 -o /tmp/gaia-guardian-test guardian/src/gaia-guardian.c
/tmp/gaia-guardian-test &
gpid=$!
sleep 1
kill "$gpid" 2>/dev/null || true
wait "$gpid" 2>/dev/null || true

echo "[3] nftables (checagem sintática)"
if command -v nft >/dev/null 2>&1; then
    sudo -n nft -c -f security/network/gaia-cve-2026-98432-shield.nft
fi

echo "[4] Pacote gaiaos-core"
deb="$(scripts/build-gaia-deb.sh)"
listing="$(dpkg-deb -c "$deb")"
for needle in './usr/bin/gaia-update' './usr/bin/gaia-guardian' './etc/sysctl.d/99-gaia-memory-mglru.conf'; do
    case "$listing" in
        *"$needle"*) ;;
        *) echo "pacote sem $needle" >&2; exit 1 ;;
    esac
done
test "$(dpkg-deb -f "$deb" Package)" = "gaiaos-core"
echo "OK $deb"
