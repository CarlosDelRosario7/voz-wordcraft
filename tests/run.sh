#!/usr/bin/env bash
# Pruebas rápidas, sin red y sin tocar la instalación real del usuario.
set -Eeuo pipefail

ROOT=$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/voz-wordcraft-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export VOZ_WORDCRAFT_HOME="$TMP/data"
export VOZ_WORDCRAFT_CONFIG_DIR="$XDG_CONFIG_HOME/voz-wordcraft"
export VOZ_WORDCRAFT_CACHE_DIR="$XDG_CACHE_HOME/voz-wordcraft"
mkdir -p "$HOME" "$VOZ_WORDCRAFT_HOME" "$VOZ_WORDCRAFT_CONFIG_DIR" "$VOZ_WORDCRAFT_CACHE_DIR"

PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    printf '  ok  %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf '  FALLO  %s\n' "$1" >&2
}

assert_eq() {
    local descripcion="$1" esperado="$2" obtenido="$3"
    if [ "$esperado" = "$obtenido" ]; then
        ok "$descripcion"
    else
        fail "$descripcion (esperado: '$esperado', obtenido: '$obtenido')"
    fi
}

assert_ok() {
    local descripcion="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        ok "$descripcion"
    else
        fail "$descripcion"
    fi
}

assert_falla() {
    local descripcion="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        fail "$descripcion (debía fallar)"
    else
        ok "$descripcion"
    fi
}

echo "== Sintaxis =="
for archivo in "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/src/lib.sh" "$ROOT/src/espeak-ng" "$ROOT/src/voz-wordcraft"; do
    if bash -n "$archivo"; then
        ok "bash -n $(basename "$archivo")"
    else
        fail "bash -n $(basename "$archivo")"
    fi
done

echo "== Catálogo y configuración =="
# shellcheck source=../src/lib.sh
. "$ROOT/src/lib.sh"

cargar_config
assert_eq "modo por defecto" "online" "$MODO"
assert_eq "voz online por defecto" "es-MX-DaliaNeural" "$VOZ_ONLINE"
assert_eq "voz offline por defecto" "es_ES-sharvard-medium" "$VOZ_OFFLINE"
assert_eq "speaker por defecto" "1" "$VOZ_OFFLINE_SPEAKER"
assert_eq "tiempo offline por defecto" "60" "$TIEMPO_MAX_OFFLINE"

assert_eq "Dalia se resuelve online" "online|es-MX-DaliaNeural|" "$(resolver_voz Dalia)"
assert_eq "SharvardF se resuelve offline" "offline|es_ES-sharvard-medium|1" "$(resolver_voz SharvardF)"
assert_eq "SharvardM se resuelve offline" "offline|es_ES-sharvard-medium|0" "$(resolver_voz SharvardM)"
assert_eq "Daniela se resuelve offline" "offline|es_AR-daniela-high|" "$(resolver_voz Daniela)"
assert_eq "MBROLA se resuelve offline" "offline|mb-es3|" "$(resolver_voz MBROLA)"
assert_eq "nombre de SharvardF" "SharvardF" "$(nombre_offline es_ES-sharvard-medium 1)"
assert_eq "nombre de SharvardM" "SharvardM" "$(nombre_offline es_ES-sharvard-medium 0)"
assert_eq "nombre online" "Dalia" "$(nombre_voz es-MX-DaliaNeural)"
assert_eq "md5 Sharvard" "77e6f9c26e92799fb04bb90b46bf1834" "$(md5_modelo es_ES-sharvard-medium)"
assert_eq "md5 config Sharvard" "e49cab310ce362145f7d94b347c291ff" "$(md5_config_modelo es_ES-sharvard-medium)"
assert_falla "voz desconocida" resolver_voz NoExiste

assert_eq "primera voz offline" "SharvardF" "$(catalogo_offline | head -n 1 | cut -d'|' -f1)"

guardar_config
assert_ok "configuración guardada" test -s "$CONF"
MODO=offline
VOZ_OFFLINE=es_AR-daniela-high
VOZ_OFFLINE_SPEAKER=""
guardar_config
cargar_config
assert_eq "modo guardado" "offline" "$MODO"
assert_eq "voz offline guardada" "es_AR-daniela-high" "$VOZ_OFFLINE"
assert_eq "speaker vacío guardado" "" "$VOZ_OFFLINE_SPEAKER"

cat > "$CONF" <<'EOF'
MODO=inventado
VOZ_ONLINE=
VOZ_OFFLINE=
VOZ_OFFLINE_SPEAKER=abc
TIEMPO_MAX_OFFLINE=1
AVISOS=no
EOF
cargar_config
assert_eq "modo inválido se corrige" "online" "$MODO"
assert_eq "voz online vacía se corrige" "es-MX-DaliaNeural" "$VOZ_ONLINE"
assert_eq "voz offline vacía se corrige" "es_ES-sharvard-medium" "$VOZ_OFFLINE"
assert_eq "speaker inválido se limpia" "" "$VOZ_OFFLINE_SPEAKER"
assert_eq "tiempo mínimo" "5" "$TIEMPO_MAX_OFFLINE"
assert_eq "avisos no" "no" "$AVISOS"

echo "== Modelos =="
assert_falla "Sharvard no instalada al principio" modelo_instalado es_ES-sharvard-medium
printf 'modelo' > "$VOCES_DIR/es_ES-sharvard-medium.onnx"
printf '{}' > "$VOCES_DIR/es_ES-sharvard-medium.onnx.json"
assert_ok "Sharvard instalada con modelo y config" modelo_instalado es_ES-sharvard-medium
rm -f "$VOCES_DIR/es_ES-sharvard-medium.onnx.json"
assert_falla "Sharvard incompleta" modelo_instalado es_ES-sharvard-medium
printf '{}' > "$VOCES_DIR/es_ES-sharvard-medium.onnx.json"

echo "== Edge TTS simulado =="
mkdir -p "$VOZ_WORDCRAFT_HOME/venv/bin"
cat > "$VOZ_WORDCRAFT_HOME/venv/bin/edge-tts" <<'EOF'
#!/usr/bin/env bash
salida=""
while [ $# -gt 0 ]; do
    case "$1" in
        --write-media) salida="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done
[ -n "$salida" ] || exit 2
printf 'mp3-de-prueba' > "$salida"
EOF
chmod +x "$VOZ_WORDCRAFT_HOME/venv/bin/edge-tts"
rm -f "$VOZ_WORDCRAFT_CACHE_DIR/online"/*
VOZ_ONLINE=es-MX-DaliaNeural
if generar_online "Hola desde la prueba" 180; then
    ok "generar_online devuelve éxito"
    if [ -s "$AUDIO_FILE" ]; then ok "generar_online crea el MP3"; else fail "generar_online crea el MP3"; fi
    assert_eq "el archivo online es MP3" "mp3" "${AUDIO_FILE##*.}"
else
    fail "generar_online devuelve éxito"
fi

echo "== Piper simulado =="
mkdir -p "$VOZ_WORDCRAFT_HOME/piper"
cat > "$VOZ_WORDCRAFT_HOME/piper/piper" <<'EOF'
#!/usr/bin/env bash
salida=""
while [ $# -gt 0 ]; do
    case "$1" in
        --output_file) salida="${2:-}"; shift 2 ;;
        *) shift ;;
    esac
done
[ -n "$salida" ] || exit 2
cat >/dev/null
printf 'wav-de-prueba' > "$salida"
EOF
chmod +x "$VOZ_WORDCRAFT_HOME/piper/piper"
mkdir -p "$VOZ_WORDCRAFT_HOME/piper/espeak-ng-data"
printf 'modelo' > "$VOCES_DIR/es_ES-sharvard-medium.onnx"
printf '{}' > "$VOCES_DIR/es_ES-sharvard-medium.onnx.json"
VOZ_OFFLINE=es_ES-sharvard-medium
VOZ_OFFLINE_SPEAKER=1
if generar_offline "Hola desde la prueba" 180; then
    ok "generar_offline devuelve éxito"
    if [ -s "$AUDIO_FILE" ]; then ok "generar_offline crea el WAV"; else fail "generar_offline crea el WAV"; fi
    assert_eq "el archivo offline es WAV" "wav" "${AUDIO_FILE##*.}"
else
    fail "generar_offline devuelve éxito"
fi

echo "== Red simulada =="
mkdir -p "$TMP/bin"
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '200'
EOF
chmod +x "$TMP/bin/curl"
PATH="$TMP/bin:$PATH"
rm -f "$NET_STATE"
assert_ok "hay_internet con respuesta 200" hay_internet
assert_eq "estado de red online" "online" "$(cut -d'|' -f1 "$NET_STATE")"
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '000'
EOF
chmod +x "$TMP/bin/curl"
rm -f "$NET_STATE"
assert_falla "hay_internet sin respuesta" hay_internet
assert_eq "estado de red offline" "offline" "$(cut -d'|' -f1 "$NET_STATE")"

echo "== CLI =="
assert_eq "CLI version" "voz-wordcraft 1.0.0" "$("$ROOT/src/voz-wordcraft" version)"
assert_ok "CLI listar" "$ROOT/src/voz-wordcraft" listar
assert_ok "CLI ayuda" "$ROOT/src/voz-wordcraft" ayuda
assert_ok "install.sh --help" "$ROOT/install.sh" --help
assert_ok "uninstall.sh --help" "$ROOT/uninstall.sh" --help

echo
if [ "$FAIL" -eq 0 ]; then
    printf 'Todas las pruebas pasaron (%s).\n' "$PASS"
    exit 0
fi
printf 'Fallaron %s prueba(s); %s pasaron.\n' "$FAIL" "$PASS" >&2
exit 1
