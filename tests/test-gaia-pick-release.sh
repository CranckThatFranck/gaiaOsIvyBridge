#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp)"
cat > "$tmp" << 'EOF'
[
  {
    "tag_name": "ivybridge-v1.0",
    "assets": [
      {"name": "gaiaos-core_1.0.0+ivybridge1_amd64.deb", "digest": "sha256:aaa", "browser_download_url": "https://example.invalid/old.deb"}
    ]
  },
  {
    "tag_name": "gaiaos-core-1.0.1+ivybridge1",
    "assets": [
      {"name": "gaiaos-core_1.0.1+ivybridge1_amd64.deb", "digest": "sha256:bbb", "browser_download_url": "https://github.com/example/1.deb"}
    ]
  },
  {
    "tag_name": "gaiaos-core-1.0.2+ivybridge1",
    "assets": [
      {"name": "gaiaos-core_1.0.2+ivybridge1_amd64.deb", "digest": "sha256:ccc", "browser_download_url": "https://github.com/example/2.deb"}
    ]
  },
  {
    "tag_name": "gaiaos-core-1.0.0+ivybridge1",
    "assets": [
      {"name": "gaiaos-core_1.0.0+ivybridge1_amd64.deb", "digest": "sha256:ddd", "browser_download_url": "https://github.com/example/0.deb"}
    ]
  }
]
EOF
out="$("$ROOT/bin/gaia-pick-release" "$tmp")"
ver="$(printf '%s\n' "$out" | sed -n '1p')"
url="$(printf '%s\n' "$out" | sed -n '2p')"
digest="$(printf '%s\n' "$out" | sed -n '3p')"
test "$ver" = "1.0.2+ivybridge1"
test "$url" = "https://github.com/example/2.deb"
test "$digest" = "ccc"
rm -f "$tmp"
echo "pick ok"
