#!/usr/bin/env bash
# Funciones compartidas por el adaptador espeak-ng y el comando voz-wordcraft.
# No se modifica WordCraft: él sigue llamando a "espeak-ng" y este adaptador
# traduce esa llamada a Edge TTS (online) o Piper/MBROLA (offline).

set -u

# El directorio de este archivo permite instalar el proyecto en cualquier ruta.
LIB_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE="${VOZ_WORDCRAFT_HOME:-$LIB_DIR}"
CONF_DIR="${VOZ_WORDCRAFT_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/voz-wordcraft}"
CACHE="${VOZ_WORDCRAFT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/voz-wordcraft}"
CONF="$CONF_DIR/config"
PIPER_DIR="$BASE/piper"
PIPER_BIN="$PIPER_DIR/piper"
VOCES_DIR="$BASE/voces"
MBROLA_DIR="$BASE/mbrola"
MBROLA_BIN="$MBROLA_DIR/bin/mbrola"
ESPEAK_BIN="$MBROLA_DIR/bin/espeak-ng"
MBROLA_DATA="$MBROLA_DIR/data"
ESPEAK_DATA="$MBROLA_DIR/espeak-ng-data"
MBROLA_VOICE="$MBROLA_DATA/mbrola/es3/es3"
EDGE_BIN="$BASE/venv/bin/edge-tts"
# shellcheck disable=SC2034 # lo usan src/espeak-ng y src/voz-wordcraft
REAL_ESPEAK_FILE="$BASE/real-espeak"
VERSION_FILE="$BASE/VERSION"
LOG="$CACHE/voz.log"
NET_STATE="$CACHE/net.state"
ESTADO_EFECTIVO="$CACHE/ultimo-estado"
EDGE_CHECK_URL="https://speech.platform.bing.com/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=6A5AA1D4EAFF4E9FB37E23D68491D6F4"

mkdir -p "$CONF_DIR" "$CACHE" "$VOCES_DIR" 2>/dev/null || true

version_instalada() {
    if [ -r "$VERSION_FILE" ]; then
        tr -d '[:space:]' < "$VERSION_FILE"
    elif [ -r "$LIB_DIR/../VERSION" ]; then
        tr -d '[:space:]' < "$LIB_DIR/../VERSION"
    else
        printf 'desconocida\n'
    fi
}

cargar_config() {
    MODO=online
    VOZ_ONLINE=es-MX-DaliaNeural
    VOZ_OFFLINE=es_ES-sharvard-medium
    VOZ_OFFLINE_SPEAKER=1
    TIEMPO_MAX_OFFLINE=60
    AVISOS=si
    if [ -r "$CONF" ]; then
        # shellcheck disable=SC1090
        . "$CONF"
    fi
    case "${MODO:-}" in
        online|offline) ;;
        *) MODO=online ;;
    esac
    [ -n "${VOZ_ONLINE:-}" ] || VOZ_ONLINE=es-MX-DaliaNeural
    [ -n "${VOZ_OFFLINE:-}" ] || VOZ_OFFLINE=es_ES-sharvard-medium
    case "${VOZ_OFFLINE_SPEAKER:-}" in
        ''|*[!0-9]*) VOZ_OFFLINE_SPEAKER="" ;;
    esac
    case "${TIEMPO_MAX_OFFLINE:-}" in ''|*[!0-9]*) TIEMPO_MAX_OFFLINE=60 ;; esac
    [ "$TIEMPO_MAX_OFFLINE" -lt 5 ] && TIEMPO_MAX_OFFLINE=5
    [ "$TIEMPO_MAX_OFFLINE" -gt 180 ] && TIEMPO_MAX_OFFLINE=180
    [ "${AVISOS:-si}" = no ] || AVISOS=si
    return 0
}

guardar_config() {
    local tmp
    mkdir -p "$CONF_DIR"
    tmp=$(mktemp "$CONF_DIR/.config.XXXXXX") || return 1
    {
        echo "# Configuración de voz-wordcraft para WordCraft"
        echo "# Modo: online (Edge; si no hay internet pasa a offline) | offline (siempre local)"
        echo "MODO=$MODO"
        echo
        echo "# Voz online (Edge TTS). Ejemplo: es-MX-DaliaNeural, es-ES-ElviraNeural"
        echo "VOZ_ONLINE=$VOZ_ONLINE"
        echo
        echo "# Voz offline (Piper o MBROLA). Ejemplo: es_ES-sharvard-medium, es_AR-daniela-high, mb-es3"
        echo "VOZ_OFFLINE=$VOZ_OFFLINE"
        echo "VOZ_OFFLINE_SPEAKER=$VOZ_OFFLINE_SPEAKER"
        echo
        echo "# Segundos máximos que se espera a la voz offline antes de usar el respaldo rápido"
        echo "TIEMPO_MAX_OFFLINE=$TIEMPO_MAX_OFFLINE"
        echo
        echo "# Avisos de escritorio: si | no"
        echo "AVISOS=$AVISOS"
    } > "$tmp"
    mv "$tmp" "$CONF"
}

catalogo_online() {
    cat <<'EOF'
Dalia|es-MX-DaliaNeural|México|femenina
Elvira|es-ES-ElviraNeural|España|femenina
Salome|es-CO-SalomeNeural|Colombia|femenina
Paloma|es-US-PalomaNeural|EE. UU. latino|femenina
Camila|es-PE-CamilaNeural|Perú|femenina
Elena|es-AR-ElenaNeural|Argentina|femenina
Valentina|es-UY-ValentinaNeural|Uruguay|femenina
Ximena|es-ES-XimenaNeural|España|femenina
Alvaro|es-ES-AlvaroNeural|España|masculina
EOF
}

catalogo_offline() {
    cat <<'EOF'
SharvardF|es_ES-sharvard-medium|España|femenina|medium|77 MB|es/es_ES/sharvard/medium/es_ES-sharvard-medium|1
SharvardM|es_ES-sharvard-medium|España|masculina|medium|77 MB|es/es_ES/sharvard/medium/es_ES-sharvard-medium|0
Daniela|es_AR-daniela-high|Argentina|femenina|high|114 MB|es/es_AR/daniela/high/es_AR-daniela-high|
MBROLA|mb-es3|España|femenina|mbrola|1,6 MB||
DaveFX|es_ES-davefx-medium|España|masculina|medium|63 MB|es/es_ES/davefx/medium/es_ES-davefx-medium|
Claude|es_MX-claude-high|México|masculina|high|63 MB|es/es_MX/claude/high/es_MX-claude-high|
Ald|es_MX-ald-medium|México|masculina|medium|63 MB|es/es_MX/ald/medium/es_MX-ald-medium|
EOF
}

md5_modelo() {
    case "$1" in
        es_ES-sharvard-medium) printf '77e6f9c26e92799fb04bb90b46bf1834\n' ;;
        es_AR-daniela-high) printf 'e373fb657c93877dbc438badeadff4cb\n' ;;
        es_ES-davefx-medium) printf 'dc515cd4ecc5f6f72fe14a941188fc9c\n' ;;
        es_MX-claude-high) printf 'cb1966e0ff20ca3aa010f6c9a0ce296a\n' ;;
        es_MX-ald-medium) printf '86374058e59b41ac3b7fe4181e1daad6\n' ;;
        *) return 1 ;;
    esac
}

md5_config_modelo() {
    case "$1" in
        es_ES-sharvard-medium) printf 'e49cab310ce362145f7d94b347c291ff\n' ;;
        es_AR-daniela-high) printf 'b68d699a1779d98ee94c0cd9a08ba95b\n' ;;
        es_ES-davefx-medium) printf 'dd157b5eaf6930bf949cf416d9a9307a\n' ;;
        es_MX-claude-high) printf '36882201922fabb409f18d284af3eddd\n' ;;
        es_MX-ald-medium) printf 'aedc07cd37e61360144f04aebb05f7dd\n' ;;
        *) return 1 ;;
    esac
}

norm() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _.-'
}

modelo_instalado() {
    local id="$1"
    if [ "$id" = "mb-es3" ]; then
        [ -x "$ESPEAK_BIN" ] && [ -x "$MBROLA_BIN" ] && [ -s "$MBROLA_VOICE" ] && [ -d "$ESPEAK_DATA" ]
        return
    fi
    [ -s "$VOCES_DIR/$id.onnx" ] && [ -s "$VOCES_DIR/$id.onnx.json" ]
}

nombre_voz() {
    local id="$1" name idcat _rest
    while IFS='|' read -r name idcat _rest; do
        if [ "$idcat" = "$id" ]; then
            printf '%s' "$name"
            return 0
        fi
    done < <(catalogo_online)
    while IFS='|' read -r name idcat _rest; do
        if [ "$idcat" = "$id" ]; then
            printf '%s' "$name"
            return 0
        fi
    done < <(catalogo_offline)
    printf '%s' "$id"
}

nombre_offline() {
    local id="$1" speaker="${2:-}" name idcat country gender quality size path spk
    while IFS='|' read -r name idcat country gender quality size path spk; do
        if [ "$idcat" = "$id" ] && [ "${spk:-}" = "${speaker:-}" ]; then
            printf '%s' "$name"
            return 0
        fi
    done < <(catalogo_offline)
    while IFS='|' read -r name idcat _rest; do
        if [ "$idcat" = "$id" ]; then
            printf '%s' "$name"
            return 0
        fi
    done < <(catalogo_offline)
    printf '%s' "$id"
}

resolver_voz() {
    local input="$1" name id country gender quality size path speaker n
    n=$(norm "$input")
    while IFS='|' read -r name id country gender; do
        if [ "$(norm "$name")" = "$n" ] || [ "$(norm "$id")" = "$n" ]; then
            printf 'online|%s|' "$id"
            return 0
        fi
    done < <(catalogo_online)
    while IFS='|' read -r name id country gender quality size path speaker; do
        if [ "$(norm "$name")" = "$n" ] || [ "$(norm "$id")" = "$n" ]; then
            printf 'offline|%s|%s' "$id" "${speaker:-}"
            return 0
        fi
    done < <(catalogo_offline)
    return 1
}

hay_internet() {
    local now last estado ttl code
    now=$(date +%s)
    if [ -r "$NET_STATE" ]; then
        IFS='|' read -r estado last ttl < "$NET_STATE"
        case "${last:-}" in ''|*[!0-9]*) last=0 ;; esac
        case "${ttl:-}" in ''|*[!0-9]*) ttl=30 ;; esac
        if [ $((now - last)) -lt "$ttl" ]; then
            [ "$estado" = online ]
            return
        fi
    fi
    if ! command -v curl >/dev/null 2>&1; then
        printf 'offline|%s|30\n' "$now" > "$NET_STATE" 2>/dev/null || true
        return 1
    fi
    code=$(curl -sS --connect-timeout 3 --max-time 5 -o /dev/null -w '%{http_code}' "$EDGE_CHECK_URL" 2>/dev/null || true)
    if [ "$code" = "200" ]; then
        printf 'online|%s|30\n' "$now" > "$NET_STATE" 2>/dev/null || true
        return 0
    fi
    printf 'offline|%s|30\n' "$now" > "$NET_STATE" 2>/dev/null || true
    return 1
}

marcar_servicio_caido() {
    printf 'offline|%s|60\n' "$(date +%s)" > "$NET_STATE" 2>/dev/null || true
}

log() {
    mkdir -p "$CACHE" 2>/dev/null || true
    if [ -f "$LOG" ] && [ "$(stat -c%s "$LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
        mv -f "$LOG" "$LOG.1" 2>/dev/null || true
    fi
    printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG" 2>/dev/null || true
}

avisar() {
    local msg="$1"
    [ "${AVISOS:-si}" = "si" ] || return 0
    log "AVISO: $msg"
    if command -v notify-send >/dev/null 2>&1; then
        timeout 3 notify-send -a "WordCraft" -u normal "WordCraft — Voz" "$msg" >/dev/null 2>&1 || true
    fi
}

registrar_estado() {
    local nuevo="$1" motivo="${2:-}" anterior
    anterior=$(cat "$ESTADO_EFECTIVO" 2>/dev/null || true)
    if [ "$anterior" = "$nuevo" ]; then
        return 0
    fi
    case "$nuevo" in
        offline)
            case "$motivo" in
                sin_internet)
                    avisar "Sin internet. Usando la voz offline ($(nombre_offline "$VOZ_OFFLINE" "$VOZ_OFFLINE_SPEAKER")). Volverá a la voz online cuando haya conexión."
                    ;;
                servicio)
                    avisar "El servicio de voz online no responde. Usando la voz offline ($(nombre_offline "$VOZ_OFFLINE" "$VOZ_OFFLINE_SPEAKER"))."
                    ;;
                reproduccion)
                    avisar "No se pudo reproducir la voz online. Usando la voz offline ($(nombre_offline "$VOZ_OFFLINE" "$VOZ_OFFLINE_SPEAKER"))."
                    ;;
                manual|*)
                    :
                    ;;
            esac
            ;;
        online)
            if [ "$anterior" = "offline" ]; then
                avisar "Conexión restablecida. WordCraft vuelve a la voz online ($(nombre_voz "$VOZ_ONLINE"))."
            fi
            ;;
    esac
    printf '%s\n' "$nuevo" > "$ESTADO_EFECTIVO" 2>/dev/null || true
}

AUDIO_FILE=""

generar_online() {
    local text="$1" wpm="${2:-180}" rate rate_str key mp3 edge
    AUDIO_FILE=""
    case "$wpm" in ''|*[!0-9]*) wpm=180 ;; esac
    [ "$wpm" -lt 60 ] && wpm=60
    [ "$wpm" -gt 600 ] && wpm=600
    rate=$(( (wpm * 100 / 180) - 100 ))
    [ "$rate" -lt -50 ] && rate=-50
    [ "$rate" -gt 100 ] && rate=100
    if [ "$rate" -ge 0 ]; then
        rate_str="+${rate}%"
    else
        rate_str="${rate}%"
    fi
    edge="$EDGE_BIN"
    [ -x "$edge" ] || edge=$(command -v edge-tts 2>/dev/null || true)
    [ -n "$edge" ] || return 1
    mkdir -p "$CACHE/online" 2>/dev/null || return 1
    key=$(printf 'online|%s|%s|%s' "$VOZ_ONLINE" "$rate_str" "$text" | sha256sum | awk '{print $1}')
    mp3="$CACHE/online/$key.mp3"
    if [ ! -s "$mp3" ]; then
        if ! timeout 15 "$edge" --voice "$VOZ_ONLINE" --rate="$rate_str" --text "$text" --write-media "$mp3" >/dev/null 2>&1; then
            rm -f "$mp3"
            return 1
        fi
    fi
    [ -s "$mp3" ] || return 1
    AUDIO_FILE="$mp3"
    log "ONLINE $VOZ_ONLINE rate=$rate_str len=${#text}"
    return 0
}

generar_mbrola() {
    local text="$1" wpm="${2:-180}" key wav espeak_data
    AUDIO_FILE=""
    case "$wpm" in ''|*[!0-9]*) wpm=180 ;; esac
    [ "$wpm" -lt 60 ] && wpm=60
    [ "$wpm" -gt 600 ] && wpm=600
    modelo_instalado mb-es3 || return 1
    espeak_data="$ESPEAK_DATA"
    [ -d "$espeak_data" ] || espeak_data="${ESPEAK_DATA_SYSTEM:-}"
    [ -n "$espeak_data" ] && [ -d "$espeak_data" ] || return 1
    mkdir -p "$CACHE/offline" 2>/dev/null || return 1
    key=$(printf 'mbrola|mb-es3|%s|%s' "$wpm" "$text" | sha256sum | awk '{print $1}')
    wav="$CACHE/offline/$key.wav"
    if [ ! -s "$wav" ]; then
        if ! printf '%s' "$text" | PATH="$MBROLA_DIR/bin:$PATH" ESPEAK_DATA_PATH="$espeak_data" XDG_DATA_DIRS="$MBROLA_DATA:/usr/local/share:/usr/share" timeout 15 "$ESPEAK_BIN" -v mb-es3 -s "$wpm" -w "$wav" >/dev/null 2>&1; then
            rm -f "$wav"
            return 1
        fi
    fi
    [ -s "$wav" ] || return 1
    AUDIO_FILE="$wav"
    log "OFFLINE mb-es3 wpm=$wpm len=${#text}"
    return 0
}

generar_offline() {
    local text="$1" wpm="${2:-180}" model cfg length_scale key wav speaker hilos
    AUDIO_FILE=""
    case "$wpm" in ''|*[!0-9]*) wpm=180 ;; esac
    [ "$wpm" -lt 60 ] && wpm=60
    [ "$wpm" -gt 600 ] && wpm=600
    if [ "$VOZ_OFFLINE" = "mb-es3" ]; then
        generar_mbrola "$text" "$wpm"
        return
    fi
    model="$VOCES_DIR/$VOZ_OFFLINE.onnx"
    cfg="$model.json"
    modelo_instalado "$VOZ_OFFLINE" || return 1
    [ -x "$PIPER_BIN" ] || return 1
    length_scale=$(awk -v w="$wpm" 'BEGIN { v=180/w; if (v<0.5) v=0.5; if (v>2.0) v=2.0; printf "%.3f", v }')
    speaker="${VOZ_OFFLINE_SPEAKER:-}"
    mkdir -p "$CACHE/offline" 2>/dev/null || return 1
    key=$(printf 'offline|%s|%s|%s|%s' "$VOZ_OFFLINE" "$speaker" "$length_scale" "$text" | sha256sum | awk '{print $1}')
    wav="$CACHE/offline/$key.wav"
    if [ ! -s "$wav" ]; then
        local args=(--model "$model" --config "$cfg" --output_file "$wav" --length_scale "$length_scale" --espeak_data "$PIPER_DIR/espeak-ng-data" --quiet)
        if [ -n "$speaker" ]; then
            args+=(--speaker "$speaker")
        fi
        hilos=$(nproc 2>/dev/null || echo 2)
        if ! printf '%s' "$text" | OMP_NUM_THREADS="$hilos" LD_LIBRARY_PATH="$PIPER_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" timeout "${TIEMPO_MAX_OFFLINE:-60}" "$PIPER_BIN" "${args[@]}" >/dev/null 2>&1; then
            rm -f "$wav"
            return 1
        fi
    fi
    [ -s "$wav" ] || return 1
    AUDIO_FILE="$wav"
    log "OFFLINE $VOZ_OFFLINE speaker=${speaker:-0} length_scale=$length_scale len=${#text}"
    return 0
}

reproductor_disponible() {
    command -v ffplay >/dev/null 2>&1 ||
        command -v mpv >/dev/null 2>&1 ||
        command -v mplayer >/dev/null 2>&1 ||
        command -v cvlc >/dev/null 2>&1 ||
        command -v paplay >/dev/null 2>&1 ||
        command -v aplay >/dev/null 2>&1
}

reproducir() {
    local file="${1:-$AUDIO_FILE}"
    [ -s "$file" ] || return 1
    if command -v ffplay >/dev/null 2>&1; then
        exec ffplay -nodisp -autoexit -loglevel quiet "$file"
    fi
    if command -v mpv >/dev/null 2>&1; then
        exec mpv --no-video --really-quiet --audio-display=no "$file"
    fi
    if command -v mplayer >/dev/null 2>&1; then
        exec mplayer -really-quiet -nolirc "$file"
    fi
    if command -v cvlc >/dev/null 2>&1; then
        exec cvlc --play-and-exit --quiet "$file"
    fi
    case "$file" in
        *.wav)
            if command -v paplay >/dev/null 2>&1; then
                exec paplay "$file"
            fi
            if command -v aplay >/dev/null 2>&1; then
                exec aplay -q "$file"
            fi
            ;;
    esac
    return 1
}

voz_efectiva() {
    if [ "$MODO" = "offline" ]; then
        printf 'offline|%s|%s\n' "$VOZ_OFFLINE" "$VOZ_OFFLINE_SPEAKER"
    elif hay_internet; then
        printf 'online|%s|\n' "$VOZ_ONLINE"
    else
        printf 'offline|%s|%s\n' "$VOZ_OFFLINE" "$VOZ_OFFLINE_SPEAKER"
    fi
}
