#!/usr/bin/env bash
# Constrói a ISO híbrida UEFI da Gaia OS Ivy Bridge Edition.
# Uso: ./scripts/build-iso.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${GAIA_WORK:-$ROOT/build/lb}"
DIST="$ROOT/dist"
THREADS="${GAIA_SQUASH_THREADS:-2}"

if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

as_root() {
    if [ -n "$SUDO" ]; then
        sudo "$@"
    else
        "$@"
    fi
}

echo "[gaia-iso] Pacote gaiaos-core..."
"$ROOT/scripts/build-gaia-deb.sh"
DEB="$(find "$DIST" -maxdepth 1 -type f -name 'gaiaos-core_*_amd64.deb' -printf '%T@ %p\n' | sort -nr | awk 'NR==1 { sub(/^[^ ]+ /, ""); print; exit }')"

# debootstrap e cpio são Depends do live-build do Trixie. dpkg -i sozinho
# deixa o pacote desconfigurado no Ubuntu 24.04 se eles ainda não estiverem instalados.
echo "[gaia-iso] Dependências do host..."
as_root apt-get update -qq
as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    debootstrap cpio debian-archive-keyring squashfs-tools xorriso \
    grub-efi-amd64-bin grub-common grub-pc-bin mtools dosfstools \
    isolinux syslinux-common ca-certificates curl wget xz-utils

if ! command -v lb >/dev/null 2>&1 || ! lb --version 2>/dev/null | grep -q '20250505'; then
    echo "[gaia-iso] Instalando live-build do Debian Trixie (o pacote do Ubuntu 24.04 é antigo demais)..."
    tmpdeb="$(mktemp --suffix=.deb)"
    curl -fsSL -o "$tmpdeb" https://deb.debian.org/debian/pool/main/l/live-build/live-build_20250505+deb13u1_all.deb
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$tmpdeb"
    rm -f "$tmpdeb"
fi

echo "[gaia-iso] Configurando live-build em $WORK"
cache_keep=""
if [ -d "$WORK/cache" ]; then
    cache_keep="$(mktemp -d)"
    as_root mv "$WORK/cache" "$cache_keep/cache"
fi
as_root rm -rf "$WORK"
mkdir -p "$WORK/auto"
if [ -n "$cache_keep" ]; then
    as_root mv "$cache_keep/cache" "$WORK/cache"
    rm -rf "$cache_keep"
fi
cp "$ROOT/live-build/auto/config" "$WORK/auto/config"
chmod 755 "$WORK/auto/config"

(
    cd "$WORK"
    as_root lb config
)

as_root mkdir -p "$WORK/config/hooks/normal" "$WORK/config/hooks/live" \
    "$WORK/config/archives" "$WORK/config/packages.chroot" \
    "$WORK/config/includes.chroot_after_packages" "$WORK/config/package-lists"
as_root cp "$ROOT/live-build/package-lists/gaia.list.chroot" "$WORK/config/package-lists/"
as_root cp "$ROOT/live-build/hooks/normal/"*.chroot "$WORK/config/hooks/normal/"
as_root cp "$ROOT/live-build/hooks/live/"*.chroot "$WORK/config/hooks/live/"
as_root chmod 755 "$WORK/config/hooks/normal/"*.chroot "$WORK/config/hooks/live/"*.chroot
as_root cp "$ROOT/live-build/archives/"*.pref.chroot "$WORK/config/archives/"
as_root cp -a "$ROOT/live-build/includes/." "$WORK/config/includes.chroot_after_packages/"
as_root chmod 755 "$WORK/config/includes.chroot_after_packages/usr/share/calamares/helpers/calamares-sources-final"
as_root chmod 440 "$WORK/config/includes.chroot_after_packages/etc/sudoers.d/gaia-live"
as_root cp "$DEB" "$WORK/config/packages.chroot/"
as_root mkdir -p "$WORK/config/bootloaders/grub-pc"
as_root cp -a "$ROOT/live-build/bootloaders/grub-pc/." "$WORK/config/bootloaders/grub-pc/"

echo "[gaia-iso] lb build (isso baixa o Trixie e comprime a imagem)..."
(
    cd "$WORK"
    as_root env MKSQUASHFS_OPTIONS="-processors ${THREADS}" DEBIAN_FRONTEND=noninteractive lb build
)

mkdir -p "$DIST"
iso_src="$(find "$WORK" -maxdepth 2 -type f \( -name '*.hybrid.iso' -o -name '*.iso' \) ! -name '*.iso.zsync' | head -1)"
if [ -z "$iso_src" ]; then
    echo "[gaia-iso] ISO não encontrada em $WORK" >&2
    exit 1
fi
OUT="$DIST/gaiaos-ivybridge-1.0-amd64.iso"
cp -f "$iso_src" "$OUT"
if [ -f "$WORK/chroot/etc/gaiaos/build-versions.txt" ]; then
    cp -f "$WORK/chroot/etc/gaiaos/build-versions.txt" "$DIST/VERSIONS.txt"
fi
(
    cd "$DIST"
    sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256"
)
echo "[gaia-iso] Pronta: $OUT"
ls -lh "$OUT" "$OUT.sha256"
if [ -f "$DIST/VERSIONS.txt" ]; then
    echo "----- VERSIONS -----"
    cat "$DIST/VERSIONS.txt"
fi
