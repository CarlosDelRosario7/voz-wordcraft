#!/usr/bin/env bash
# Instalador local de voz-wordcraft. No usa sudo ni modifica WordCraft.
set -Eeuo pipefail

ROOT=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VERSION=$(tr -d '[:space:]' < "$ROOT/VERSION")
PIPER_RELEASE="2023.11.14-2"
PIPER_BASE_URL="https://github.com/rhasspy/piper/releases/download/$PIPER_RELEASE"

YES=0
ONLINE_ONLY=0
WITH_DANIELA=0
WITH_MBROLA=0
MBROLA_OK=0
DO_UNINSTALL=0
PURGE=0
NO_PATH=0
PREFIX="${VOZ_WORDCRAFT_PREFIX:-$HOME/.local}"

if [ -t 1 ]; then
    BOLD=$'\033[1m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
    BLUE=$'\033[34m'
    RESET=$'\033[0m'
else
    BOLD=""
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
    RESET=""
fi

info() { printf '%s==>%s %s\n' "$BLUE" "$RESET" "$*"; }
ok() { printf '%s  OK%s %s\n' "$GREEN" "$RESET" "$*"; }
warn() { printf '%sAviso:%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
die() {
    printf '%sError:%s %s\n' "$RED" "$RESET" "$*" >&2
    exit 1
}

uso() {
    cat <<EOF
voz-wordcraft $VERSION — instalador

Uso:
  ./install.sh [opciones]

Opciones:
  -y, --yes             No pedir confirmación
  --online-only         Instalar solo la voz online (sin Piper ni voces offline)
  --with-daniela        Descargar también la voz offline Daniela (114 MB)
  --with-mbrola         Instalar MBROLA es3 como voz offline opcional
                        (solo Debian/Ubuntu/Kali; requiere libespeak-ng1.
                        Si falta el binario, se extrae del paquete espeak-ng)
  --prefix DIR          Instalar los comandos en DIR/bin (por defecto ~/.local)
  --no-path             No añadir DIR/bin al PATH de los archivos de shell
  --uninstall           Desinstalar (equivale a ./uninstall.sh)
  --purge               Con --uninstall, borrar también la configuración
  -h, --help            Esta ayuda
  -V, --version         Ver la versión

Rutas por defecto:
  Comandos:  ~/.local/bin
  Datos:     ~/.local/share/voz-wordcraft
  Config:    ~/.config/voz-wordcraft/config
  Caché:     ~/.cache/voz-wordcraft

El instalador no usa sudo. Si ya existe un espeak-ng en ~/.local/bin, lo
guarda como espeak-ng.voz-wordcraft-backup y lo restaura al desinstalar.
EOF
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) YES=1 ;;
            --online-only) ONLINE_ONLY=1 ;;
            --with-daniela) WITH_DANIELA=1 ;;
            --with-mbrola) WITH_MBROLA=1 ;;
            --uninstall) DO_UNINSTALL=1 ;;
            --purge) PURGE=1 ;;
            --prefix)
                [ $# -ge 2 ] || die "Falta el valor de --prefix"
                PREFIX="$2"
                shift
                ;;
            --prefix=*) PREFIX="${1#*=}" ;;
            --no-path) NO_PATH=1 ;;
            -h|--help) uso; exit 0 ;;
            -V|--version) echo "voz-wordcraft $VERSION"; exit 0 ;;
            *)
                die "Opción no reconocida: $1 (usa --help)"
                ;;
        esac
        shift
    done

    [ -n "$PREFIX" ] || die "--prefix no puede estar vacío"
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
    DOWNLOAD_DIR="$CACHE_DIR/downloads"
    CONF="$CONF_DIR/config"

    if [ "$DO_UNINSTALL" -eq 1 ]; then
        local args=(--prefix "$PREFIX")
        if [ "$YES" -eq 1 ]; then
            args+=(--yes)
        fi
        if [ "$PURGE" -eq 1 ]; then
            args+=(--purge)
        fi
        exec "$ROOT/uninstall.sh" "${args[@]}"
    fi
    if [ "$PURGE" -eq 1 ]; then
        die "--purge solo se usa junto con --uninstall"
    fi
    if [ "$ONLINE_ONLY" -eq 1 ] && [ "$WITH_MBROLA" -eq 1 ]; then
        die "--online-only y --with-mbrola no se pueden combinar"
    fi
    if [ "$ONLINE_ONLY" -eq 1 ] && [ "$WITH_DANIELA" -eq 1 ]; then
        warn "--with-daniela se ignora con --online-only"
    fi
}

confirmar() {
    local respuesta
    if [ "$YES" -eq 1 ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        die "No hay terminal interactiva. Vuelve a ejecutar con --yes."
    fi
    printf '\n%sSe instalará voz-wordcraft %s en:%s\n' "$BOLD" "$VERSION" "$RESET"
    printf '  Comandos: %s\n' "$BIN_DIR"
    printf '  Datos:    %s\n' "$DATA_DIR"
    printf '  Config:   %s\n' "$CONF"
    printf '  Caché:    %s\n\n' "$CACHE_DIR"
    printf 'No se usará sudo. ¿Continuar? [s/N] '
    read -r respuesta
    case "$respuesta" in
        s|S|si|sí|Si|Sí|y|Y|yes|YES) ;;
        *) echo "Instalación cancelada."; exit 0 ;;
    esac
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Falta '$1'. Instálalo con el gestor de paquetes de tu distribución."
}

check_system() {
    [ "$(uname -s)" = "Linux" ] || die "Este proyecto está pensado para Linux."
    local cmd
    for cmd in bash curl tar gzip python3 sha256sum md5sum awk sed grep install ln readlink; do
        require_cmd "$cmd"
    done
    if ! reproductor_disponible; then
        warn "No hay reproductor de audio (ffplay, mpv, mplayer, cvlc, paplay ni aplay)."
        warn "La instalación continuará, pero no se oirá la voz hasta instalar uno."
        warn "Recomendado: ffmpeg (incluye ffplay) o mpv."
    fi
    if ! command -v notify-send >/dev/null 2>&1; then
        warn "notify-send no está disponible; los avisos de escritorio serán opcionales."
    fi
}

preparar_dirs() {
    mkdir -p "$BIN_DIR" "$DATA_DIR" "$CONF_DIR" "$CACHE_DIR" "$DOWNLOAD_DIR"
    [ -w "$BIN_DIR" ] || die "No puedo escribir en $BIN_DIR"
    [ -w "$DATA_DIR" ] || die "No puedo escribir en $DATA_DIR"
    [ -w "$CONF_DIR" ] || die "No puedo escribir en $CONF_DIR"
}

download_file() {
    local url="$1" destino="$2" sha_esperado="${3:-}" tmp
    mkdir -p "$(dirname "$destino")"
    if [ -s "$destino" ] && [ -n "$sha_esperado" ]; then
        if [ "$(sha256sum "$destino" | awk '{print $1}')" = "$sha_esperado" ]; then
            ok "Descarga ya disponible: $(basename "$destino")"
            return 0
        fi
    fi
    tmp="$destino.part.$$"
    rm -f "$tmp"
    info "Descargando $(basename "$destino")..."
    if ! curl -fL --retry 3 --connect-timeout 20 --progress-bar -o "$tmp" "$url"; then
        rm -f "$tmp"
        die "No se pudo descargar $url"
    fi
    if [ -n "$sha_esperado" ]; then
        if [ "$(sha256sum "$tmp" | awk '{print $1}')" != "$sha_esperado" ]; then
            rm -f "$tmp"
            die "La suma SHA-256 de $(basename "$destino") no coincide."
        fi
    fi
    mv "$tmp" "$destino"
}

install_scripts() {
    info "Instalando comandos y adaptador..."
    install -m 755 "$ROOT/src/lib.sh" "$DATA_DIR/lib.sh"
    install -m 755 "$ROOT/src/espeak-ng" "$DATA_DIR/espeak-ng"
    install -m 755 "$ROOT/src/voz-wordcraft" "$DATA_DIR/voz-wordcraft"
    install -m 644 "$ROOT/VERSION" "$DATA_DIR/VERSION"
    install -m 644 "$ROOT/config.example" "$DATA_DIR/config.example"
    ok "Scripts instalados en $DATA_DIR"
}

find_real_espeak() {
    local candidato
    for candidato in "$BIN_DIR/espeak-ng.voz-wordcraft-backup" "$BIN_DIR/espeak-ng" /usr/bin/espeak-ng /usr/local/bin/espeak-ng /bin/espeak-ng; do
        [ -x "$candidato" ] || continue
        if [ "$(readlink -f "$candidato")" = "$(readlink -f "$DATA_DIR/espeak-ng")" ]; then
            continue
        fi
        if grep -q 'voz-wordcraft' "$candidato" 2>/dev/null; then
            continue
        fi
        printf '%s\n' "$candidato"
        return 0
    done
    candidato=$(command -v espeak-ng 2>/dev/null || true)
    if [ -n "$candidato" ] && [ -x "$candidato" ]; then
        if [ "$(readlink -f "$candidato")" != "$(readlink -f "$DATA_DIR/espeak-ng")" ] &&
            ! grep -q 'voz-wordcraft' "$candidato" 2>/dev/null; then
            printf '%s\n' "$candidato"
            return 0
        fi
    fi
    return 1
}

es_nuestro_enlace() {
    local enlace="$1" destino="$2"
    [ -L "$enlace" ] && [ "$(readlink -f "$enlace")" = "$(readlink -f "$destino")" ]
}

install_adapter() {
    local actual="$BIN_DIR/espeak-ng" backup="$BIN_DIR/espeak-ng.voz-wordcraft-backup" real=""
    info "Instalando adaptador espeak-ng..."
    mkdir -p "$BIN_DIR"
    if [ -e "$actual" ] || [ -L "$actual" ]; then
        if es_nuestro_enlace "$actual" "$DATA_DIR/espeak-ng"; then
            :
        elif grep -q 'voz-wordcraft' "$actual" 2>/dev/null; then
            :
        else
            if [ -e "$backup" ] || [ -L "$backup" ]; then
                die "Ya existe $backup y $actual no es de voz-wordcraft. Muévelo o bórralo antes de continuar."
            fi
            mv "$actual" "$backup"
            real="$backup"
            ok "Guardado el espeak-ng anterior en $backup"
        fi
    fi
    if [ -z "$real" ]; then
        real=$(find_real_espeak || true)
    fi
    if [ -n "$real" ]; then
        printf '%s\n' "$real" > "$DATA_DIR/real-espeak"
        ok "espeak-ng real para otras aplicaciones: $real"
    else
        : > "$DATA_DIR/real-espeak"
        warn "No se encontró un espeak-ng real. El adaptador seguirá funcionando con WordCraft,"
        warn "pero las llamadas de otras aplicaciones a espeak-ng no tendrán reenvío."
    fi
    rm -f "$actual"
    ln -s "$DATA_DIR/espeak-ng" "$actual"
    ok "Adaptador: $actual -> $DATA_DIR/espeak-ng"
}

install_cli() {
    local actual="$BIN_DIR/voz-wordcraft" backup="$BIN_DIR/voz-wordcraft.pre-voz-wordcraft"
    if [ -e "$actual" ] || [ -L "$actual" ]; then
        if es_nuestro_enlace "$actual" "$DATA_DIR/voz-wordcraft"; then
            :
        elif grep -q 'voz-wordcraft' "$actual" 2>/dev/null; then
            :
        else
            if [ -e "$backup" ] || [ -L "$backup" ]; then
                die "Ya existe $backup y $actual no es de voz-wordcraft. Muévelo o bórralo antes de continuar."
            fi
            mv "$actual" "$backup"
            warn "Guardado el comando anterior en $backup"
        fi
    fi
    rm -f "$actual"
    ln -s "$DATA_DIR/voz-wordcraft" "$actual"
    ok "Comando: $actual"
}

install_config() {
    mkdir -p "$CONF_DIR"
    if [ -e "$CONF" ]; then
        ok "Conservando la configuración existente: $CONF"
    else
        install -m 644 "$ROOT/config.example" "$CONF"
        ok "Configuración inicial: $CONF"
    fi
}

install_edge_tts() {
    local edge="$DATA_DIR/venv/bin/edge-tts" global=""
    info "Preparando Edge TTS (voz online)..."
    if [ -x "$edge" ] && "$edge" --version >/dev/null 2>&1; then
        ok "Edge TTS ya está instalado en el entorno local."
        return 0
    fi
    rm -rf "$DATA_DIR/venv"
    if python3 -m venv "$DATA_DIR/venv" >/dev/null 2>&1; then
        if "$DATA_DIR/venv/bin/python" -m pip install --disable-pip-version-check --upgrade pip >/dev/null 2>&1 &&
            "$DATA_DIR/venv/bin/python" -m pip install --disable-pip-version-check --upgrade edge-tts; then
            if [ -x "$edge" ] && "$edge" --version >/dev/null 2>&1; then
                ok "Edge TTS instalado en $DATA_DIR/venv"
                return 0
            fi
        fi
    fi
    global=$(command -v edge-tts 2>/dev/null || true)
    if [ -n "$global" ] && "$global" --version >/dev/null 2>&1; then
        warn "No se pudo crear el entorno local, pero se usará el edge-tts del sistema: $global"
        return 0
    fi
    die "No se pudo instalar edge-tts. En Debian/Ubuntu/Kali necesitas python3-venv y conexión a internet."
}

install_piper() {
    local arch asset sha tar archivo_tmp
    if [ -x "$PIPER_BIN" ] && [ -d "$PIPER_DIR/espeak-ng-data" ]; then
        ok "Piper ya está instalado."
        return 0
    fi
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            asset="piper_linux_x86_64.tar.gz"
            sha="a50cb45f355b7af1f6d758c1b360717877ba0a398cc8cbe6d2a7a3a26e225992"
            ;;
        aarch64|arm64)
            asset="piper_linux_aarch64.tar.gz"
            sha="fea0fd2d87c54dbc7078d0f878289f404bd4d6eea6e7444a77835d1537ab88eb"
            ;;
        armv7l|armhf)
            asset="piper_linux_armv7l.tar.gz"
            sha="c6946fcd57c705ed1d4666ea880f80ba0bbbd14de62ecbdd13460baf3bac8e37"
            ;;
        *)
            die "Arquitectura no soportada por Piper: $arch"
            ;;
    esac
    tar="$DOWNLOAD_DIR/$asset"
    download_file "$PIPER_BASE_URL/$asset" "$tar" "$sha"
    info "Extrayendo Piper..."
    archivo_tmp=$(mktemp -d "$CACHE_DIR/.piper.XXXXXX")
    tar -xzf "$tar" -C "$archivo_tmp"
    [ -x "$archivo_tmp/piper/piper" ] || die "El paquete de Piper no tiene el binario esperado."
    rm -rf "$DATA_DIR/piper.new"
    cp -a "$archivo_tmp/piper" "$DATA_DIR/piper.new"
    chmod +x "$DATA_DIR/piper.new/piper" "$DATA_DIR/piper.new/espeak-ng" 2>/dev/null || true
    rm -rf "$DATA_DIR/piper"
    mv "$DATA_DIR/piper.new" "$DATA_DIR/piper"
    chmod +x "$DATA_DIR/piper/piper" "$DATA_DIR/piper/espeak-ng" 2>/dev/null || true
    rm -rf "$archivo_tmp"
    ok "Piper instalado en $DATA_DIR/piper"
}

install_voice() {
    local id="$1" nombre="$2" linea name idcat country gender quality size path speaker
    local base onnx json tmp_onnx tmp_json md5_esperado md5_json_esperado
    linea=$(catalogo_offline | awk -F'|' -v id="$id" '$2==id {print; exit}')
    [ -n "$linea" ] || die "No conozco la voz offline $id"
    IFS='|' read -r name idcat country gender quality size path speaker <<< "$linea"
    onnx="$VOCES_DIR/$id.onnx"
    json="$onnx.json"
    if [ -s "$onnx" ] && [ -s "$json" ]; then
        ok "Voz $nombre ya instalada."
        return 0
    fi
    md5_esperado=$(md5_modelo "$id") || die "Falta la suma de verificación de $id"
    md5_json_esperado=$(md5_config_modelo "$id") || die "Falta la suma de verificación de la configuración de $id"
    base="https://huggingface.co/rhasspy/piper-voices/resolve/main/$path"
    mkdir -p "$VOCES_DIR"
    tmp_onnx="$VOCES_DIR/.$id.onnx.part.$$"
    tmp_json="$VOCES_DIR/.$id.onnx.json.part.$$"
    rm -f "$tmp_onnx" "$tmp_json"
    info "Descargando voz $nombre ($size)..."
    if ! curl -fL --retry 3 --connect-timeout 20 --progress-bar -o "$tmp_onnx" "$base.onnx"; then
        rm -f "$tmp_onnx"
        die "No se pudo descargar el modelo de $nombre."
    fi
    if [ "$(md5sum "$tmp_onnx" | awk '{print $1}')" != "$md5_esperado" ]; then
        rm -f "$tmp_onnx"
        die "La suma MD5 del modelo de $nombre no coincide."
    fi
    if ! curl -fL --retry 3 --connect-timeout 20 --progress-bar -o "$tmp_json" "$base.onnx.json"; then
        rm -f "$tmp_onnx" "$tmp_json"
        die "No se pudo descargar la configuración de $nombre."
    fi
    if [ "$(md5sum "$tmp_json" | awk '{print $1}')" != "$md5_json_esperado" ]; then
        rm -f "$tmp_onnx" "$tmp_json"
        die "La suma MD5 de la configuración de $nombre no coincide."
    fi
    mv "$tmp_onnx" "$onnx"
    mv "$tmp_json" "$json"
    ok "Voz $nombre instalada."
}

instalar_mbrola() {
    local tmp real="" mbdeb es3deb data_src data_pkg="" espeak_deb=""
    if modelo_instalado mb-es3; then
        ok "MBROLA es3 ya está instalada."
        return 0
    fi
    if ! command -v apt-get >/dev/null 2>&1 || ! command -v dpkg-deb >/dev/null 2>&1; then
        warn "MBROLA opcional solo está automatizado en Debian/Ubuntu/Kali (apt-get + dpkg-deb)."
        return 1
    fi
    tmp=$(mktemp -d "$CACHE_DIR/.mbrola.XXXXXX")
    info "Descargando paquetes de MBROLA..."
    if ! (cd "$tmp" && apt-get -o Acquire::Retries=3 download mbrola mbrola-es3 >/dev/null 2>&1); then
        warn "No se pudieron descargar mbrola y mbrola-es3."
        warn "En Debian/Ubuntu puede que necesites habilitar contrib/non-free."
        rm -rf "$tmp"
        return 1
    fi
    mbdeb=$(find "$tmp" -maxdepth 1 -type f -name 'mbrola_*.deb' ! -name 'mbrola-es3*' -print -quit)
    es3deb=$(find "$tmp" -maxdepth 1 -type f -name 'mbrola-es3_*.deb' -print -quit)
    if [ -z "$mbdeb" ] || [ -z "$es3deb" ]; then
        warn "No se encontraron los paquetes .deb esperados."
        rm -rf "$tmp"
        return 1
    fi
    real=$(find_real_espeak || true)
    if [ -z "$real" ]; then
        info "No se encontró espeak-ng; descargando el binario para MBROLA..."
        if ! (cd "$tmp" && apt-get -o Acquire::Retries=3 download espeak-ng >/dev/null 2>&1); then
            warn "No se pudo descargar espeak-ng."
            rm -rf "$tmp"
            return 1
        fi
        espeak_deb=$(find "$tmp" -maxdepth 1 -type f -name 'espeak-ng_*.deb' ! -name 'espeak-ng-data*' -print -quit)
        if [ -z "$espeak_deb" ]; then
            warn "No se encontró el paquete espeak-ng."
            rm -rf "$tmp"
            return 1
        fi
        mkdir -p "$tmp/espeak"
        dpkg-deb -x "$espeak_deb" "$tmp/espeak"
        real="$tmp/espeak/usr/bin/espeak-ng"
        if [ ! -x "$real" ]; then
            warn "El paquete espeak-ng no contiene el binario esperado."
            rm -rf "$tmp"
            return 1
        fi
    fi
    if ldd "$real" 2>/dev/null | grep -q 'not found'; then
        warn "espeak-ng necesita bibliotecas que no están instaladas:"
        ldd "$real" 2>/dev/null | grep 'not found' | sed 's/^/  /' >&2
        warn "Instala libespeak-ng1, libpcaudio0 y libsonic0 (o el paquete espeak-ng)."
        rm -rf "$tmp"
        return 1
    fi
    mkdir -p "$tmp/mbrola" "$tmp/es3"
    dpkg-deb -x "$mbdeb" "$tmp/mbrola"
    dpkg-deb -x "$es3deb" "$tmp/es3"
    data_src=""
    for data_pkg in /usr/lib/*/espeak-ng-data /usr/share/espeak-ng-data; do
        if [ -d "$data_pkg" ] && [ -s "$data_pkg/phontab" ]; then
            data_src="$data_pkg"
            break
        fi
    done
    if [ -z "$data_src" ]; then
        info "Descargando datos de espeak-ng para MBROLA..."
        if ! (cd "$tmp" && apt-get -o Acquire::Retries=3 download espeak-ng-data >/dev/null 2>&1); then
            warn "No se pudieron descargar los datos de espeak-ng."
            rm -rf "$tmp"
            return 1
        fi
        mkdir -p "$tmp/data"
        dpkg-deb -x "$(find "$tmp" -maxdepth 1 -type f -name 'espeak-ng-data_*.deb' -print -quit)" "$tmp/data"
        data_src=$(find "$tmp/data" -type d -name espeak-ng-data -print -quit)
    fi
    if [ -z "$data_src" ] || [ ! -d "$data_src" ]; then
        warn "No se encontraron los datos de espeak-ng."
        rm -rf "$tmp"
        return 1
    fi
    mkdir -p "$MBROLA_DIR/bin" "$MBROLA_DIR/data" "$MBROLA_DIR/espeak-ng-data"
    install -m 755 "$tmp/mbrola/usr/bin/mbrola" "$MBROLA_DIR/bin/mbrola"
    install -m 755 "$real" "$MBROLA_DIR/bin/espeak-ng"
    if [ -d "$tmp/es3/usr/share/mbrola" ]; then
        cp -a "$tmp/es3/usr/share/mbrola/." "$MBROLA_DIR/data/mbrola/"
    fi
    rm -rf "$MBROLA_DIR/espeak-ng-data.new"
    cp -a "$data_src" "$MBROLA_DIR/espeak-ng-data.new"
    rm -rf "$MBROLA_DIR/espeak-ng-data"
    mv "$MBROLA_DIR/espeak-ng-data.new" "$MBROLA_DIR/espeak-ng-data"
    if [ ! -s "$MBROLA_VOICE" ]; then
        warn "No se encontró la voz mb-es3 en los datos de espeak-ng."
        rm -rf "$MBROLA_DIR"
        rm -rf "$tmp"
        return 1
    fi
    if [ ! -s "$ESPEAK_DATA/mbrola_ph/es3_phtrans" ]; then
        warn "No se encontró es3_phtrans en los datos de espeak-ng."
        rm -rf "$MBROLA_DIR"
        rm -rf "$tmp"
        return 1
    fi
    info "Probando MBROLA es3..."
    if ! printf 'Prueba de voz MBROLA.\n' | PATH="$MBROLA_DIR/bin:$PATH" ESPEAK_DATA_PATH="$ESPEAK_DATA" XDG_DATA_DIRS="$MBROLA_DATA:/usr/local/share:/usr/share" timeout 20 "$ESPEAK_BIN" -v mb-es3 -s 180 -w "$tmp/prueba.wav" >/dev/null 2>&1; then
        warn "MBROLA no respondió a la prueba. Se descarta la instalación opcional."
        rm -rf "$MBROLA_DIR"
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$tmp"
    ok "MBROLA es3 instalada."
}

add_path_block() {
    local archivo
    if [ "$NO_PATH" -eq 1 ]; then
        warn "No se modificará el PATH (--no-path)."
        return 0
    fi
    case ":$PATH:" in
        *":$BIN_DIR:"*)
            ok "$BIN_DIR ya está en el PATH."
            return 0
            ;;
    esac
    local archivos=()
    for archivo in "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -e "$archivo" ]; then
            archivos+=("$archivo")
        fi
    done
    if [ ${#archivos[@]} -eq 0 ]; then
        touch "$HOME/.profile"
        archivos+=("$HOME/.profile")
    fi
    for archivo in "${archivos[@]}"; do
        if grep -q '>>> voz-wordcraft >>>' "$archivo" 2>/dev/null; then
            continue
        fi
        {
            printf '\n# >>> voz-wordcraft >>>\n'
            printf 'case ":$PATH:" in\n'
            printf '  *":%s:"*) ;;\n' "$BIN_DIR"
            printf '  *) export PATH="%s:$PATH" ;;\n' "$BIN_DIR"
            printf 'esac\n'
            printf '# <<< voz-wordcraft <<<\n'
        } >> "$archivo"
        ok "PATH actualizado en $archivo"
    done
    warn "Cierra sesión y vuelve a entrar (o ejecuta: source ~/.profile) para que WordCraft encuentre el adaptador."
}

resumen() {
    echo
    printf '%sInstalación completada: voz-wordcraft %s%s\n' "$BOLD" "$VERSION" "$RESET"
    echo "  Comando:   $BIN_DIR/voz-wordcraft"
    echo "  Datos:     $DATA_DIR"
    echo "  Config:    $CONF"
    echo "  Caché:     $CACHE_DIR"
    echo
    echo "Voz online:  Dalia (es-MX-DaliaNeural), si hay internet."
    if [ "$ONLINE_ONLY" -eq 1 ]; then
        echo "Voz offline: no instalada (--online-only)."
    else
        echo "Voz offline: Sharvard F (es_ES-sharvard-medium, speaker 1)."
        if [ "$WITH_DANIELA" -eq 1 ]; then
            echo "              Daniela también descargada (opcional)."
        fi
    fi
    if [ "$MBROLA_OK" -eq 1 ]; then
        echo "MBROLA:      es3 instalada como respaldo rápido opcional."
    fi
    echo
    echo "Prueba ahora:  voz-wordcraft probar"
    echo "Ver estado:    voz-wordcraft estado"
    echo "Menú:          voz-wordcraft"
    echo
    echo "Abre WordCraft (o reinícialo si ya estaba abierto) y usa Ctrl+Alt+Espacio"
    echo "para leer el texto seleccionado. No hace falta Wine: WordCraft es nativo."
}

main() {
    parse_args "$@"
    # Cargar el catálogo compartido con el CLI y el adaptador.
    export VOZ_WORDCRAFT_HOME="$DATA_DIR"
    export VOZ_WORDCRAFT_CONFIG_DIR="$CONF_DIR"
    export VOZ_WORDCRAFT_CACHE_DIR="$CACHE_DIR"
    # shellcheck source=src/lib.sh
    . "$ROOT/src/lib.sh"

    check_system
    confirmar
    preparar_dirs

    install_scripts
    install_adapter
    install_cli
    install_config
    install_edge_tts

    if [ "$ONLINE_ONLY" -eq 0 ]; then
        install_piper
        install_voice es_ES-sharvard-medium "Sharvard F"
        if [ "$WITH_DANIELA" -eq 1 ]; then
            install_voice es_AR-daniela-high "Daniela"
        fi
    else
        warn "Modo --online-only: no se instalarán Piper ni las voces offline."
    fi

    if [ "$WITH_MBROLA" -eq 1 ]; then
        if instalar_mbrola; then
            MBROLA_OK=1
        else
            warn "MBROLA no se instaló; el resto de voz-wordcraft sigue funcionando."
        fi
    fi

    add_path_block
    resumen
}

main "$@"
