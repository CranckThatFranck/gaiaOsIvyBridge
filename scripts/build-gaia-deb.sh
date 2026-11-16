#!/usr/bin/env bash
# Monta dist/gaiaos-core_<versão>_amd64.deb a partir das fontes do repositório.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

CONTROL="$ROOT/packaging/gaiaos-core/DEBIAN/control"
VERSION="$(awk -F': ' '/^Version:/ {print $2; exit}' "$CONTROL")"
ARCH="$(awk -F': ' '/^Architecture:/ {print $2; exit}' "$CONTROL")"
mkdir -p "$ROOT/dist" "$STAGE/DEBIAN"

cp "$ROOT/packaging/gaiaos-core/DEBIAN/control" "$STAGE/DEBIAN/control"
cp "$ROOT/packaging/gaiaos-core/DEBIAN/postinst" "$STAGE/DEBIAN/postinst"
cp "$ROOT/packaging/gaiaos-core/DEBIAN/prerm" "$STAGE/DEBIAN/prerm"
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/prerm"

install -d "$STAGE/usr/bin" "$STAGE/usr/lib/gaiaos" "$STAGE/usr/share/gaiaos" \
    "$STAGE/usr/share/applications" "$STAGE/lib/systemd/system"

install -m 755 "$ROOT/bin/gaia-sec-apply" "$STAGE/usr/bin/gaia-sec-apply"
install -m 755 "$ROOT/bin/gaia-pkg" "$STAGE/usr/bin/gaia-pkg"
install -m 755 "$ROOT/bin/gaia-snapshot" "$STAGE/usr/bin/gaia-snapshot"
install -m 755 "$ROOT/bin/gaia-lean-services" "$STAGE/usr/bin/gaia-lean-services"
install -m 755 "$ROOT/bin/gaia-update" "$STAGE/usr/bin/gaia-update"
install -m 755 "$ROOT/bin/gaia-cpufreq" "$STAGE/usr/bin/gaia-cpufreq"
install -m 755 "$ROOT/bin/gaia-postinstall" "$STAGE/usr/bin/gaia-postinstall"
install -m 755 "$ROOT/bin/gaia-sec-verify" "$STAGE/usr/bin/gaia-sec-verify"
install -m 755 "$ROOT/bin/gaia-agy-yolo.sh" "$STAGE/usr/bin/agy"
install -m 755 "$ROOT/bin/gaia-live-session" "$STAGE/usr/lib/gaiaos/gaia-live-session"

cp -a "$ROOT/packaging/etc-overlay/etc" "$STAGE/"
mkdir -p "$STAGE/etc/profile.d"
install -m 644 "$ROOT/bin/gaia-agy-yolo.sh" "$STAGE/etc/profile.d/gaia-agy.sh"
install -m 755 "$ROOT/guardian/src/gaia-gemini-advisor" "$STAGE/usr/bin/gaia-gemini-advisor"
install -m 755 "$ROOT/guardian/ui/gaia-guardian-ui" "$STAGE/usr/bin/gaia-guardian-ui"
install -m 644 "$ROOT/guardian/ui/gaia-guardian.desktop" "$STAGE/usr/share/applications/gaia-guardian.desktop"

cc=${CC:-gcc}
"$cc" -O2 -pipe -Wall -Wextra -std=c11 -o "$STAGE/usr/bin/gaia-guardian" "$ROOT/guardian/src/gaia-guardian.c"
strip "$STAGE/usr/bin/gaia-guardian"

cp -a "$ROOT/security" "$STAGE/usr/share/gaiaos/security"
cp -a "$ROOT/performance" "$STAGE/usr/share/gaiaos/performance"
cp -a "$ROOT/systemd" "$STAGE/usr/share/gaiaos/systemd"
cp -a "$ROOT/integrations" "$STAGE/usr/share/gaiaos/integrations"
mkdir -p "$STAGE/usr/share/gaiaos/tests"
install -m 755 "$ROOT/tests/verify-security.sh" "$STAGE/usr/share/gaiaos/tests/verify-security.sh"
install -m 644 "$ROOT/performance/initramfs-modules" "$STAGE/usr/share/gaiaos/initramfs-modules"
install -m 644 "$ROOT/packaging/etc-overlay/usr/share/gaiaos/guardian.env.example" \
    "$STAGE/usr/share/gaiaos/guardian.env.example"

mkdir -p "$STAGE/etc/sysctl.d" "$STAGE/etc/tmpfiles.d" "$STAGE/etc/gaiaos/security" \
    "$STAGE/etc/opt/chrome/policies/managed" "$STAGE/etc/default"
install -m 644 "$ROOT/security/kernel/98-gaia-security-cve-2026-98432.conf" \
    "$STAGE/etc/sysctl.d/98-gaia-security-cve-2026-98432.conf"
install -m 644 "$ROOT/performance/99-gaia-memory-mglru.conf" \
    "$STAGE/etc/sysctl.d/99-gaia-memory-mglru.conf"
install -m 644 "$ROOT/performance/gaia-mglru-tmpfiles.conf" \
    "$STAGE/etc/tmpfiles.d/gaia-mglru.conf"
install -m 644 "$ROOT/security/network/gaia-cve-2026-98432-shield.nft" \
    "$STAGE/etc/gaiaos/security/gaia-cve-2026-98432-shield.nft"
chmod 600 "$STAGE/etc/gaiaos/security/gaia-cve-2026-98432-shield.nft"
install -m 644 "$ROOT/security/node/gaia-node-shield.cjs" \
    "$STAGE/etc/gaiaos/security/gaia-node-shield.cjs"
install -m 644 "$ROOT/security/php/99-gaia-php2shell-shield.ini" \
    "$STAGE/etc/gaiaos/security/99-gaia-php2shell-shield.ini"
install -m 644 "$ROOT/performance/guardian.conf" "$STAGE/etc/gaiaos/guardian.conf"
printf 'ivybridge\n' > "$STAGE/etc/gaiaos/edition"
install -m 644 "$ROOT/performance/gaia-chrome-performance.json" \
    "$STAGE/etc/opt/chrome/policies/managed/gaia-performance.json"

for unit in gaia-guardian.service gaia-security-shield.service gaia-update.service \
    gaia-update.timer gaia-cpufreq.service gaia-live-session.service; do
    install -m 644 "$ROOT/systemd/$unit" "$STAGE/lib/systemd/system/$unit"
done

OUT="$ROOT/dist/gaiaos-core_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT" >/dev/null
echo "$OUT"
