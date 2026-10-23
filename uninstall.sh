#!/usr/bin/env bash
# Desinstalador de voz-wordcraft. No usa sudo.
set -Eeuo pipefail

ROOT=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VERSION=$(tr -d '[:space:]' < "$ROOT/VERSION")

YES=0
PURGE=0
PREFIX="${VOZ_WORDCRAFT_PREFIX:-$HOME/.local}"

if [ -t 1 ]; then
    BOLD=$'\033[1m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
    RESET=$'\033[0m'
else
    BOLD=""
    GREEN=""
    YELLOW=""
    RED=""
    RESET=""
fi

info() { printf '==> %s\n' "$*"; }
ok() { printf '%s  OK%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%sAviso:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die() {
    printf '%sError:%s %s\n' "$RED" "$RESET" "$*" >&2
    exit 1
}

uso() {
    cat <<EOF
voz-wordcraft $VERSION — desinstalador

Uso:
  ./uninstall.sh [opciones]

Opciones:
  -y, --yes       No pedir confirmación
  --purge         Borrar también la configuración (~/.config/voz-wordcraft)
  --prefix DIR    Directorio donde están los comandos (por defecto ~/.local)
  -h, --help      Esta ayuda
  -V, --version   Ver la versión

Por defecto se eliminan los comandos, el adaptador, Piper, las voces descargadas
y la caché. La configuración se conserva para una futura reinstalación; usa
--purge si también quieres borrarla.
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) YES=1 ;;
            --purge) PURGE=1 ;;
            --prefix)
                [ $# -ge 2 ] || die "Falta el valor de --prefix"
                PREFIX="$2"
                shift
                ;;
            --prefix=*) PREFIX="${1#*=}" ;;
            -h|--help) uso; exit 0 ;;
            -V|--version) echo "voz-wordcraft $VERSION"; exit 0 ;;
            *) die "Opción no reconocida: $1 (usa --help)" ;;
        esac
        shift
    done
    # shellcheck disable=SC2088
    case "$PREFIX" in
        "~") PREFIX="$HOME" ;;
        "~/"*) PREFIX="$HOME/${PREFIX#\~/}" ;;
        /*) ;;
        *) PREFIX="$PWD/$PREFIX" ;;
    esac
    PREFIX="${PREFIX%/}"
    [ -n "$PREFIX" ] || PREFIX="/"
    BIN_DIR="$PREFIX/bin"
    DATA_DIR="${VOZ_WORDCRAFT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/voz-wordcraft}"
    CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/voz-wordcraft"
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/voz-wordcraft"
}

confirmar() {
    local respuesta
    if [ "$YES" -eq 1 ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        die "No hay terminal interactiva. Vuelve a ejecutar con --yes."
    fi
    printf '\n%sSe desinstalará voz-wordcraft.%s\n' "$BOLD" "$RESET"
    echo "  Comandos: $BIN_DIR/voz-wordcraft y $BIN_DIR/espeak-ng"
    echo "  Datos:    $DATA_DIR (Piper, voces y MBROLA)"
    echo "  Caché:    $CACHE_DIR"
    if [ "$PURGE" -eq 1 ]; then
        echo "  Config:   $CONF_DIR (se borrará con --purge)"
    else
        echo "  Config:   $CONF_DIR (se conservará)"
    fi
    printf '\n¿Continuar? [s/N] '
    read -r respuesta
    case "$respuesta" in
        s|S|si|sí|Si|Sí|y|Y|yes|YES) ;;
        *) echo "Desinstalación cancelada."; exit 0 ;;
    esac
}

remove_path_block() {
    local archivo tmp
    for archivo in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$archivo" ] || continue
        if grep -q '>>> voz-wordcraft >>>' "$archivo" 2>/dev/null; then
            tmp="$archivo.voz-wordcraft.tmp.$$"
            awk '
                /# >>> voz-wordcraft >>>/ { dentro=1; next }
                /# <<< voz-wordcraft <<</ { dentro=0; next }
                !dentro { print }
            ' "$archivo" > "$tmp"
            mv "$tmp" "$archivo"
            ok "PATH limpiado en $archivo"
        fi
    done
}

remove_link_restore() {
    local enlace="$1" destino="$2" backup="$3"
    if [ -L "$enlace" ] && [ "$(readlink -f "$enlace")" = "$(readlink -f "$destino")" ]; then
        rm -f "$enlace"
        ok "Eliminado $enlace"
    elif [ -e "$enlace" ] && grep -q 'voz-wordcraft' "$enlace" 2>/dev/null; then
        rm -f "$enlace"
        ok "Eliminado $enlace"
    elif [ -e "$enlace" ] || [ -L "$enlace" ]; then
        warn "No se toca $enlace porque no parece de voz-wordcraft."
    fi
    if [ -e "$backup" ] || [ -L "$backup" ]; then
        if [ ! -e "$enlace" ] && [ ! -L "$enlace" ]; then
            mv "$backup" "$enlace"
            ok "Restaurado $enlace"
        else
            warn "No se restauró $backup porque $enlace ya existe."
        fi
    fi
}

main() {
    parse_args "$@"
    confirmar
    info "Desinstalando voz-wordcraft..."
    remove_path_block
    remove_link_restore "$BIN_DIR/espeak-ng" "$DATA_DIR/espeak-ng" "$BIN_DIR/espeak-ng.voz-wordcraft-backup"
    remove_link_restore "$BIN_DIR/voz-wordcraft" "$DATA_DIR/voz-wordcraft" "$BIN_DIR/voz-wordcraft.pre-voz-wordcraft"
    if [ -d "$DATA_DIR" ] || [ -L "$DATA_DIR" ]; then
        rm -rf "$DATA_DIR"
        ok "Eliminados datos y voces: $DATA_DIR"
    fi
    if [ -d "$CACHE_DIR" ] || [ -L "$CACHE_DIR" ]; then
        rm -rf "$CACHE_DIR"
        ok "Eliminada caché: $CACHE_DIR"
    fi
    if [ "$PURGE" -eq 1 ]; then
        if [ -d "$CONF_DIR" ] || [ -L "$CONF_DIR" ]; then
            rm -rf "$CONF_DIR"
            ok "Eliminada configuración: $CONF_DIR"
        fi
    elif [ -e "$CONF_DIR/config" ]; then
        echo "  Configuración conservada: $CONF_DIR/config"
    fi
    echo
    echo "voz-wordcraft desinstalado."
    if [ "$PURGE" -eq 0 ] && [ -e "$CONF_DIR/config" ]; then
        echo "Para borrar también la configuración: ./uninstall.sh --purge"
    fi
}

main "$@"
