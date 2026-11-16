# Escudo Node2Shell / TLS / DNS. Apps que definem NODE_OPTIONS por conta própria prevalecem.
if [ -f /etc/gaiaos/security/gaia-node-shield.cjs ]; then
    case "${NODE_OPTIONS:-}" in
        *gaia-node-shield.cjs*) ;;
        "") export NODE_OPTIONS="--require /etc/gaiaos/security/gaia-node-shield.cjs" ;;
        *) export NODE_OPTIONS="--require /etc/gaiaos/security/gaia-node-shield.cjs ${NODE_OPTIONS}" ;;
    esac
fi
export LIBVA_DRIVER_NAME="${LIBVA_DRIVER_NAME:-i965}"
