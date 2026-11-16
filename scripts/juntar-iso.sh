#!/usr/bin/env bash
# Junta os pedaços publicados quando a ISO passa de 2 GiB.
# Uso: ./scripts/juntar-iso.sh [diretório com os .part e o .sha256]
set -euo pipefail
DIR="${1:-.}"
cd "$DIR"
parts=(gaiaos-ivybridge-1.0-amd64.iso.part*)
if [ ! -e "${parts[0]}" ]; then
    echo "Nenhum pedaço gaiaos-ivybridge-1.0-amd64.iso.part* em $DIR" >&2
    exit 1
fi
cat gaiaos-ivybridge-1.0-amd64.iso.part* > gaiaos-ivybridge-1.0-amd64.iso
sha256sum -c gaiaos-ivybridge-1.0-amd64.iso.sha256
echo "ISO recomposta e conferida."
