# voz-wordcraft

[English version](README.en.md) · [Avisos de terceros](THIRD_PARTY_NOTICES.md)

Integración **no oficial** para que WordCraft lea en voz alta con una voz femenina en español sobre Linux, sin Wine y sin `sudo`.

WordCraft es una aplicación nativa (AppImage). Este proyecto no modifica WordCraft: instala un adaptador llamado `espeak-ng` en `~/.local/bin` que intercepta las llamadas de voz de WordCraft y las convierte en audio con **Edge TTS** (online) o **Piper/MBROLA** (offline).

> **Aviso:** proyecto independiente, sin relación con WordCraft ni con Microsoft. WordCraft no se incluye en este repositorio.

## Qué hace

- **Voz online por defecto:** Dalia (`es-MX-DaliaNeural`), femenina y natural. Requiere internet.
- **Voz offline por defecto:** Sharvard F (`es_ES-sharvard-medium`, speaker `1`), femenina y bastante rápida en CPUs modestas.
- **Caída automática:** si no hay internet o Edge TTS falla, usa la voz offline y avisa por notificación. Cuando vuelve la conexión, regresa sola a Dalia.
- **Modo offline fijo:** usa siempre la voz local, aunque haya internet.
- **Sin `sudo`:** todo se instala en el directorio del usuario.
- **Sin tocar WordCraft:** no hay que editar el AppImage ni usar Wine.
- **Reenvío seguro:** si otra aplicación llama a `espeak-ng` sin `--stdin`, el adaptador reenvía la llamada al `espeak-ng` real (si existe).

## Requisitos

- Linux **x86_64**, **aarch64** o **armv7l**.
- WordCraft 0.10.x probado. Debe ser el AppImage nativo de Linux.
- `bash`, `curl`, `tar`, `gzip`, `python3`, `python3-venv`, `md5sum`, `sha256sum`, `awk`, `sed`, `grep`.
- Un reproductor de audio: `ffplay` (paquete `ffmpeg`), `mpv`, `mplayer`, `cvlc`, `paplay` o `aplay`.
- Internet para la instalación y para la voz online.
- Opcional: `notify-send` para avisos de escritorio y `whiptail` para el menú gráfico.

Espacio aproximado: **~130 MB** para Piper + Sharvard F; **~245 MB** si añades Daniela; **~30 MB** si añades MBROLA.

En Debian/Ubuntu/Kali, si falta algo:

```bash
sudo apt install ffmpeg python3-venv curl
```

El instalador **no usa `sudo`**; solo necesitas permisos de usuario en tu `$HOME`.

## Instalación

```bash
git clone https://github.com/CarlosDelRosario7/voz-wordcraft.git
cd voz-wordcraft
./install.sh
```

El instalador muestra las rutas y pide confirmación. Para una instalación desatendida:

```bash
./install.sh --yes
```

Al terminar, si `~/.local/bin` no estaba en el `PATH`, se añade un bloque a `~/.profile`, `~/.bashrc` o `~/.zshrc`. Cierra sesión y vuelve a entrar, o ejecuta:

```bash
source ~/.profile
```

Comprueba que todo está listo:

```bash
voz-wordcraft estado
voz-wordcraft probar
```

### Opciones del instalador

| Opción | Qué hace |
| --- | --- |
| `-y`, `--yes` | No pedir confirmación. |
| `--online-only` | Instalar solo la voz online; sin Piper ni voces offline. |
| `--with-daniela` | Descargar también Daniela (`es_AR-daniela-high`, 114 MB). |
| `--with-mbrola` | Instalar MBROLA es3 como respaldo offline opcional (solo Debian/Ubuntu/Kali). |
| `--prefix DIR` | Instalar los comandos en `DIR/bin` (por defecto `~/.local`). |
| `--no-path` | No modificar los archivos de shell para añadir `DIR/bin` al `PATH`. |
| `--uninstall` | Desinstalar. |
| `--purge` | Con `--uninstall`, borrar también la configuración. |

Ejemplos:

```bash
./install.sh --yes --with-daniela
./install.sh --yes --with-mbrola
./install.sh --yes --online-only
./install.sh --prefix "$HOME/.local"
```

## Uso con WordCraft

1. Abre WordCraft (reinícialo si ya estaba abierto durante la instalación).
2. Selecciona un texto.
3. Pulsa **`Ctrl+Alt+Espacio`** (en el binario aparece como `Mod+Alt+Space`).
4. Espera unos segundos: la primera frase de cada voz puede tardar más.

WordCraft llama a `espeak-ng -s <palabras_por_minuto> [-v <idioma>] --stdin` y espera a que termine. El adaptador hace el resto.

## Comandos

```bash
voz-wordcraft                     # menú interactivo
voz-wordcraft estado              # modo, internet, voces, reproductor y caché
voz-wordcraft listar              # voces online y offline disponibles
voz-wordcraft probar [voz]        # escuchar una muestra
voz-wordcraft usar [online|offline] <voz>
voz-wordcraft online              # modo online con caída automática a offline
voz-wordcraft offline             # modo offline fijo
voz-wordcraft descargar <voz>     # descargar una voz offline de Piper
voz-wordcraft limpiar             # vaciar la caché de frases
voz-wordcraft diagnostico         # comprobar dependencias y estado
voz-wordcraft version             # versión instalada
voz-wordcraft ayuda               # ayuda
```

Ejemplos:

```bash
voz-wordcraft probar Dalia
voz-wordcraft probar SharvardF
voz-wordcraft usar Dalia
voz-wordcraft usar SharvardF
voz-wordcraft usar Daniela
voz-wordcraft usar MBROLA
voz-wordcraft descargar Daniela
voz-wordcraft online
voz-wordcraft offline
```

## Modos

### Online (por defecto)

Usa **Dalia**. Si no hay internet o el servicio falla, usa la voz offline configurada y muestra un aviso. Cuando vuelve la conexión, la siguiente frase vuelve a usar Dalia automáticamente.

```bash
voz-wordcraft online
```

### Offline fijo

Usa siempre la voz local, aunque haya internet, hasta que ejecutes `voz-wordcraft online`.

```bash
voz-wordcraft offline
```

## Voces

### Online (Edge TTS)

| Nombre | ID | País | Género |
| --- | --- | --- | --- |
| Dalia | `es-MX-DaliaNeural` | México | femenina |
| Elvira | `es-ES-ElviraNeural` | España | femenina |
| Salome | `es-CO-SalomeNeural` | Colombia | femenina |
| Paloma | `es-US-PalomaNeural` | EE. UU. latino | femenina |
| Camila | `es-PE-CamilaNeural` | Perú | femenina |
| Elena | `es-AR-ElenaNeural` | Argentina | femenina |
| Valentina | `es-UY-ValentinaNeural` | Uruguay | femenina |
| Ximena | `es-ES-XimenaNeural` | España | femenina |
| Alvaro | `es-ES-AlvaroNeural` | España | masculina |

### Offline (Piper / MBROLA)

| Nombre | ID | País | Género | Calidad | Tamaño | Notas |
| --- | --- | --- | --- | --- | --- | --- |
| **SharvardF** | `es_ES-sharvard-medium` | España | femenina | media | 77 MB | Por defecto; speaker `1`. |
| SharvardM | `es_ES-sharvard-medium` | España | masculina | media | 77 MB | Speaker `0`. |
| Daniela | `es_AR-daniela-high` | Argentina | femenina | alta | 114 MB | Opcional; lenta en CPUs modestas. |
| MBROLA | `mb-es3` | España | femenina | MBROLA | ~30 MB | Opcional; robótica pero casi instantánea. |
| DaveFX | `es_ES-davefx-medium` | España | masculina | media | 63 MB | Opcional. |
| Claude | `es_MX-claude-high` | México | masculina | alta | 63 MB | Opcional. |
| Ald | `es_MX-ald-medium` | México | masculina | media | 63 MB | Opcional. |

Las voces Piper se descargan bajo demanda:

```bash
voz-wordcraft descargar Daniela
voz-wordcraft descargar DaveFX
```

`--with-daniela` descarga Daniela durante la instalación. `--with-mbrola` instala MBROLA es3 y su respaldo privado de `espeak-ng` (solo en Debian/Ubuntu/Kali; requiere `libespeak-ng1` y los datos de `espeak-ng`).

## Rutas

| Qué | Ruta por defecto |
| --- | --- |
| Comandos | `~/.local/bin/voz-wordcraft` y `~/.local/bin/espeak-ng` |
| Datos, Piper y voces | `~/.local/share/voz-wordcraft/` |
| Configuración | `~/.config/voz-wordcraft/config` |
| Caché y registro | `~/.cache/voz-wordcraft/` |

Puedes cambiar las rutas con las variables `VOZ_WORDCRAFT_HOME`, `VOZ_WORDCRAFT_CONFIG_DIR`, `VOZ_WORDCRAFT_CACHE_DIR` y `--prefix`.

## Cómo funciona

1. El instalador crea `~/.local/bin/espeak-ng` como enlace al adaptador `~/.local/share/voz-wordcraft/espeak-ng`.
2. WordCraft ejecuta `espeak-ng ... --stdin` y escribe el texto por la entrada estándar.
3. El adaptador:
   - en modo online, genera un MP3 con `edge-tts` y lo reproduce;
   - en modo offline, genera un WAV con Piper (o MBROLA) y lo reproduce;
   - si la voz online falla, usa la offline;
   - si la voz offline falla o tarda demasiado, intenta MBROLA es3 si está instalada;
   - como último recurso, usa `spd-say` con voz femenina.
4. Las frases se guardan en caché por texto, voz y velocidad para no regenerarlas.
5. Si otra aplicación llama a `espeak-ng` sin `--stdin`, el adaptador reenvía la llamada al `espeak-ng` real. Si no existe, muestra un error y no rompe WordCraft.

El instalador guarda el `espeak-ng` anterior como `~/.local/bin/espeak-ng.voz-wordcraft-backup` y lo restaura al desinstalar.

## Privacidad

- **Online:** el texto se envía a los servidores de Microsoft (Edge TTS) para generar el audio.
- **Offline:** todo se genera en tu equipo con Piper o MBROLA; no se envía texto a internet.
- La caché local guarda los audios generados en `~/.cache/voz-wordcraft/`. Puedes borrarla con `voz-wordcraft limpiar`.
- El registro `~/.cache/voz-wordcraft/voz.log` guarda metadatos (voz, velocidad, longitud del texto), no el texto completo.

## Rendimiento

Medido en un Intel Celeron 3855U (2 núcleos), orientativo:

| Voz | Frase corta | Frase larga |
| --- | --- | --- |
| Sharvard F (Piper) | ~5,5 s | ~30 s |
| Daniela (Piper) | ~16-20 s | ~30-40 s |
| MBROLA es3 | < 0,3 s | ~1 s |
| Dalia (online) | +1-3 s de red | +1-3 s de red |

La primera frase de cada voz puede tardar más por la carga del modelo. Si usas Daniela y tu equipo es lento, sube `TIEMPO_MAX_OFFLINE` en la configuración (por ejemplo, a `120`). Si prefieres que el respaldo rápido entre antes, bájalo.

## Solución de problemas

**`voz-wordcraft: command not found`**

Añade `~/.local/bin` al `PATH` y vuelve a entrar en la sesión:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
source ~/.profile
```

O ejecuta el comando con la ruta completa: `~/.local/bin/voz-wordcraft`.

**WordCraft sigue usando una voz robótica**

Comprueba que el adaptador es el primero del `PATH`:

```bash
command -v espeak-ng
# Debe mostrar /home/TU_USUARIO/.local/bin/espeak-ng
```

Si WordCraft ya estaba abierto, ciérralo y vuelve a abrirlo. También puede ayudar reiniciar la sesión.

**No se oye nada**

Instala un reproductor y prueba:

```bash
sudo apt install ffmpeg
voz-wordcraft probar SharvardF
```

**La voz online no funciona**

Comprueba internet y el diagnóstico:

```bash
voz-wordcraft diagnostico
voz-wordcraft online
```

Si no hay internet, el modo online usa la voz offline automáticamente. Para forzar la voz local: `voz-wordcraft offline`.

**La voz offline tarda demasiado**

Sharvard F es la más rápida. Daniela es más natural pero lenta. MBROLA es casi instantánea, aunque suena robótica:

```bash
./install.sh --with-mbrola
voz-wordcraft usar MBROLA
```

También puedes ajustar `TIEMPO_MAX_OFFLINE` en `~/.config/voz-wordcraft/config`.

**MBROLA no se instala**

MBROLA solo está automatizado en Debian/Ubuntu/Kali. Necesita `apt-get`, `dpkg-deb`, `libespeak-ng1` y datos de `espeak-ng`. El instalador puede descargar el binario y los datos, pero no instala bibliotecas del sistema con `sudo`.

**Quiero ver qué pasó**

```bash
tail -n 50 ~/.cache/voz-wordcraft/voz.log
```

## Desinstalación

```bash
./uninstall.sh
```

Conserva la configuración para una futura reinstalación. Para borrar también la configuración:

```bash
./uninstall.sh --purge
```

También puedes usar `./install.sh --uninstall` o `./install.sh --uninstall --purge`.

El desinstalador elimina los comandos, el adaptador, Piper, las voces descargadas, MBROLA y la caché, y restaura el `espeak-ng` anterior si lo había.

## Pruebas

```bash
./tests/run.sh
```

Las pruebas no usan red, no descargan voces y no tocan la instalación real: usan un `HOME` temporal y simulaciones de Edge TTS, Piper y la red.

## Licencia

Los scripts de este proyecto se publican bajo la licencia **MIT** (ver [LICENSE](LICENSE)). Las voces, binarios y servicios de terceros tienen sus propias licencias y **no se incluyen en el repositorio**; se descargan durante la instalación. Consulta [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

WordCraft es un proyecto independiente. Este repositorio no está afiliado a WordCraft ni a Microsoft.
