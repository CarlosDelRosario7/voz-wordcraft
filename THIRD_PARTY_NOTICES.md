# Avisos de terceros

Este repositorio contiene únicamente scripts propios bajo licencia MIT, configuración y documentación. **No se incluyen binarios, modelos de voz ni datos de terceros.** El instalador los descarga en tiempo de instalación desde sus fuentes originales.

A continuación se indican los componentes de terceros que el proyecto puede descargar o utilizar, con sus licencias y enlaces. Esta lista es informativa; las condiciones completas están en los enlaces de cada proyecto.

## Edge TTS

- **Proyecto:** [edge-tts](https://github.com/rany2/edge-tts)
- **Uso:** voz online (Dalia y otras voces de Edge).
- **Licencia:** GNU Lesser General Public License v3.0 (LGPLv3), salvo `src/edge_tts/srt_composer.py`, que usa licencia MIT.
- **Distribución:** se instala desde PyPI en un entorno virtual local durante la instalación. No se redistribuye en este repositorio.
- **Servicio:** las voces online son generadas por el servicio Edge TTS de Microsoft. El texto se envía a Microsoft. El uso del servicio está sujeto a las condiciones de Microsoft.

## Piper

- **Proyecto:** [rhasspy/piper](https://github.com/rhasspy/piper)
- **Uso:** síntesis de voz offline.
- **Licencia:** MIT.
- **Distribución:** el instalador descarga el binario oficial `piper_linux_<arquitectura>.tar.gz` de la versión `2023.11.14-2` desde GitHub Releases y verifica su SHA-256. No se redistribuye en este repositorio.

## Voces de Piper

Los modelos se descargan bajo demanda desde [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices) y se verifican con MD5. Cada modelo tiene su propia licencia:

| Voz | Modelo | Licencia | Model card |
| --- | --- | --- | --- |
| Sharvard F/M | `es_ES-sharvard-medium` | CC BY 3.0 (dataset) | [MODEL_CARD](https://huggingface.co/rhasspy/piper-voices/blob/main/es/es_ES/sharvard/medium/MODEL_CARD) |
| Daniela | `es_AR-daniela-high` | CC BY-SA 4.0 | [MODEL_CARD](https://huggingface.co/rhasspy/piper-voices/blob/main/es/es_AR/daniela/high/MODEL_CARD) |
| DaveFX | `es_ES-davefx-medium` | CC0 | [MODEL_CARD](https://huggingface.co/rhasspy/piper-voices/blob/main/es/es_ES/davefx/medium/MODEL_CARD) |
| Claude | `es_MX-claude-high` | Apache-2.0 | [MODEL_CARD](https://huggingface.co/rhasspy/piper-voices/blob/main/es/es_MX/claude/high/MODEL_CARD) |
| Ald | `es_MX-ald-medium` | Unlicense | [MODEL_CARD](https://huggingface.co/rhasspy/piper-voices/blob/main/es/es_MX/ald/medium/MODEL_CARD) |

Las licencias de los datasets y de los modelos pueden imponer condiciones de atribución o compartir igual. Consulta cada model card antes de redistribuir un modelo.

## espeak-ng

- **Proyecto:** [espeak-ng](https://github.com/espeak-ng/espeak-ng)
- **Uso:** motor de fonemas de Piper y, opcionalmente, síntesis MBROLA.
- **Licencia:** GNU General Public License v3.0 o posterior (GPLv3+), junto con las licencias de sus datos.
- **Distribución:** Piper incluye su propia copia de espeak-ng y sus datos. Para MBROLA, el instalador puede descargar el binario y los datos desde paquetes Debian (`espeak-ng`, `espeak-ng-data`). No se redistribuyen en este repositorio.

## MBROLA (opcional)

- **Proyecto:** [numediart/MBROLA](https://github.com/numediart/MBROLA)
- **Voces:** [numediart/MBROLA-voices](https://github.com/numediart/MBROLA-voices)
- **Uso:** voz offline de respaldo rápido (`mb-es3`).
- **Licencia del programa:** GNU Affero General Public License v3.0 o posterior (AGPL-3+).
- **Licencia de las voces:** cada voz tiene sus propias condiciones. La base de datos MBROLA permite su uso para sintetizar voz con MBROLA y su distribución está sujeta a las mismas condiciones que el programa; no puede venderse ni incorporarse a un producto de pago sin permiso del autor. Consulta [LICENSE.md de MBROLA-voices](https://github.com/numediart/MBROLA-voices/blob/master/LICENSE.md).
- **Distribución:** el instalador descarga `mbrola`, `mbrola-es3` y, si hace falta, `espeak-ng`/`espeak-ng-data` desde los repositorios Debian. No se redistribuyen en este repositorio.
- **Requisito:** MBROLA solo está automatizado en Debian/Ubuntu/Kali y requiere `libespeak-ng1` y los datos de espeak-ng.

## WordCraft

- **Uso:** aplicación que llama al adaptador `espeak-ng`.
- **Distribución:** WordCraft no se incluye en este repositorio. El usuario debe obtenerlo por su cuenta.
- **Relación:** este proyecto es independiente y no está afiliado a WordCraft ni a sus autores.

## Reproductores y utilidades del sistema

El proyecto puede usar `ffplay` (FFmpeg), `mpv`, `mplayer`, `cvlc`, `paplay`, `aplay`, `notify-send`, `whiptail`, `curl`, `python3` y herramientas estándar de Linux. No se redistribuyen; se usan desde el sistema del usuario y conservan sus propias licencias.

## Marcas

WordCraft, Microsoft, Edge, Piper, MBROLA y espeak-ng son marcas o proyectos de sus respectivos titulares. Este proyecto no reclama ninguna afiliación ni patrocinio.

---

# Third-party notices (English summary)

This repository contains only original MIT-licensed scripts, configuration, and documentation. **No third-party binaries, voice models, or data are included.** They are downloaded at install time from their original sources.

- **edge-tts** — LGPLv3 (except `srt_composer.py`, MIT). Installed from PyPI. Online voices are provided by Microsoft Edge TTS; text is sent to Microsoft.
- **Piper** — MIT. Official Linux binary downloaded from GitHub Releases (`2023.11.14-2`) and verified with SHA-256.
- **Piper voices** — downloaded from `rhasspy/piper-voices` and verified with MD5. Model licenses: Sharvard `es_ES-sharvard-medium` CC BY 3.0; Daniela `es_AR-daniela-high` CC BY-SA 4.0; DaveFX `es_ES-davefx-medium` CC0; Claude `es_MX-claude-high` Apache-2.0; Ald `es_MX-ald-medium` Unlicense. See each model card.
- **espeak-ng** — GPLv3+ (plus data licenses). Bundled with Piper or downloaded from Debian packages for optional MBROLA.
- **MBROLA** — program AGPL-3+; voices have their own terms and are not redistributed. Downloaded from Debian packages. Debian/Ubuntu/Kali only; requires `libespeak-ng1` and espeak-ng data.
- **WordCraft** — not included and not affiliated with this project.
- **Audio players and system utilities** — not redistributed; used from the user's system under their own licenses.

All trademarks belong to their respective owners.
