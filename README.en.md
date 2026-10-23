# voz-wordcraft

[Versión en español](README.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)

**Unofficial** integration that makes WordCraft read text aloud with a Spanish female voice on Linux, without Wine and without `sudo`.

WordCraft is a native app (AppImage). This project does not modify WordCraft: it installs an `espeak-ng` adapter in `~/.local/bin` that intercepts WordCraft's speech calls and turns them into audio with **Edge TTS** (online) or **Piper/MBROLA** (offline).

> **Notice:** independent project, not affiliated with WordCraft or Microsoft. WordCraft is not included in this repository.

## What it does

- **Default online voice:** Dalia (`es-MX-DaliaNeural`), female and natural. Requires internet.
- **Default offline voice:** Sharvard F (`es_ES-sharvard-medium`, speaker `1`), female and reasonably fast on modest CPUs.
- **Automatic fallback:** if there is no internet or Edge TTS fails, it uses the offline voice and shows a notification. When the connection returns, it switches back to Dalia automatically.
- **Fixed offline mode:** always use the local voice, even with internet.
- **No `sudo`:** everything is installed under your user directory.
- **No WordCraft changes:** no need to edit the AppImage or use Wine.
- **Safe forwarding:** if another app calls `espeak-ng` without `--stdin`, the adapter forwards the call to the real `espeak-ng` (if available).

## Requirements

- Linux **x86_64**, **aarch64**, or **armv7l**.
- WordCraft 0.10.x tested. It must be the native Linux AppImage.
- `bash`, `curl`, `tar`, `gzip`, `python3`, `python3-venv`, `md5sum`, `sha256sum`, `awk`, `sed`, `grep`.
- An audio player: `ffplay` (`ffmpeg` package), `mpv`, `mplayer`, `cvlc`, `paplay`, or `aplay`.
- Internet for installation and for the online voice.
- Optional: `notify-send` for desktop notifications and `whiptail` for the graphical menu.

Approximate disk space: **~130 MB** for Piper + Sharvard F; **~245 MB** with Daniela; **~30 MB** with MBROLA.

On Debian/Ubuntu/Kali, if something is missing:

```bash
sudo apt install ffmpeg python3-venv curl
```

The installer **does not use `sudo`**; it only needs write access to your `$HOME`.

## Installation

```bash
git clone https://github.com/CarlosDelRosario7/voz-wordcraft.git
cd voz-wordcraft
./install.sh
```

The installer shows the paths and asks for confirmation. For an unattended install:

```bash
./install.sh --yes
```

If `~/.local/bin` was not in your `PATH`, a block is added to `~/.profile`, `~/.bashrc`, or `~/.zshrc`. Log out and back in, or run:

```bash
source ~/.profile
```

Check that everything is ready:

```bash
voz-wordcraft estado
voz-wordcraft probar
```

### Installer options

| Option | What it does |
| --- | --- |
| `-y`, `--yes` | Do not ask for confirmation. |
| `--online-only` | Install only the online voice; no Piper or offline voices. |
| `--with-daniela` | Also download Daniela (`es_AR-daniela-high`, 114 MB). |
| `--with-mbrola` | Install MBROLA es3 as an optional offline backup (Debian/Ubuntu/Kali only). |
| `--prefix DIR` | Install commands in `DIR/bin` (default `~/.local`). |
| `--no-path` | Do not modify shell files to add `DIR/bin` to `PATH`. |
| `--uninstall` | Uninstall. |
| `--purge` | With `--uninstall`, also remove the configuration. |

Examples:

```bash
./install.sh --yes --with-daniela
./install.sh --yes --with-mbrola
./install.sh --yes --online-only
./install.sh --prefix "$HOME/.local"
```

## Using it with WordCraft

1. Open WordCraft (restart it if it was open during installation).
2. Select some text.
3. Press **`Ctrl+Alt+Space`** (shown as `Mod+Alt+Space` in the binary).
4. Wait a few seconds: the first sentence with each voice may take longer.

WordCraft calls `espeak-ng -s <words_per_minute> [-v <language>] --stdin` and waits for it to finish. The adapter does the rest.

## Commands

```bash
voz-wordcraft                     # interactive menu
voz-wordcraft estado              # mode, internet, voices, player, and cache
voz-wordcraft listar              # list online and offline voices
voz-wordcraft probar [voz]        # play a sample
voz-wordcraft usar [online|offline] <voz>
voz-wordcraft online              # online mode with automatic offline fallback
voz-wordcraft offline             # fixed offline mode
voz-wordcraft descargar <voz>     # download a Piper offline voice
voz-wordcraft limpiar             # clear the phrase cache
voz-wordcraft diagnostico         # check dependencies and status
voz-wordcraft version             # installed version
voz-wordcraft ayuda               # help
```

Examples:

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

## Modes

### Online (default)

Uses **Dalia**. If there is no internet or the service fails, it uses the configured offline voice and shows a notification. When the connection returns, the next sentence uses Dalia again automatically.

```bash
voz-wordcraft online
```

### Fixed offline

Always uses the local voice, even with internet, until you run `voz-wordcraft online`.

```bash
voz-wordcraft offline
```

## Voices

### Online (Edge TTS)

| Name | ID | Country | Gender |
| --- | --- | --- | --- |
| Dalia | `es-MX-DaliaNeural` | Mexico | female |
| Elvira | `es-ES-ElviraNeural` | Spain | female |
| Salome | `es-CO-SalomeNeural` | Colombia | female |
| Paloma | `es-US-PalomaNeural` | US Spanish | female |
| Camila | `es-PE-CamilaNeural` | Peru | female |
| Elena | `es-AR-ElenaNeural` | Argentina | female |
| Valentina | `es-UY-ValentinaNeural` | Uruguay | female |
| Ximena | `es-ES-XimenaNeural` | Spain | female |
| Alvaro | `es-ES-AlvaroNeural` | Spain | male |

### Offline (Piper / MBROLA)

| Name | ID | Country | Gender | Quality | Size | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| **SharvardF** | `es_ES-sharvard-medium` | Spain | female | medium | 77 MB | Default; speaker `1`. |
| SharvardM | `es_ES-sharvard-medium` | Spain | male | medium | 77 MB | Speaker `0`. |
| Daniela | `es_AR-daniela-high` | Argentina | female | high | 114 MB | Optional; slow on modest CPUs. |
| MBROLA | `mb-es3` | Spain | female | MBROLA | ~30 MB | Optional; robotic but almost instant. |
| DaveFX | `es_ES-davefx-medium` | Spain | male | medium | 63 MB | Optional. |
| Claude | `es_MX-claude-high` | Mexico | male | high | 63 MB | Optional. |
| Ald | `es_MX-ald-medium` | Mexico | male | medium | 63 MB | Optional. |

Piper voices are downloaded on demand:

```bash
voz-wordcraft descargar Daniela
voz-wordcraft descargar DaveFX
```

`--with-daniela` downloads Daniela during installation. `--with-mbrola` installs MBROLA es3 and its private `espeak-ng` backup (Debian/Ubuntu/Kali only; requires `libespeak-ng1` and `espeak-ng` data).

## Paths

| What | Default path |
| --- | --- |
| Commands | `~/.local/bin/voz-wordcraft` and `~/.local/bin/espeak-ng` |
| Data, Piper, and voices | `~/.local/share/voz-wordcraft/` |
| Configuration | `~/.config/voz-wordcraft/config` |
| Cache and log | `~/.cache/voz-wordcraft/` |

You can change the paths with `VOZ_WORDCRAFT_HOME`, `VOZ_WORDCRAFT_CONFIG_DIR`, `VOZ_WORDCRAFT_CACHE_DIR`, and `--prefix`.

## How it works

1. The installer creates `~/.local/bin/espeak-ng` as a link to the adapter `~/.local/share/voz-wordcraft/espeak-ng`.
2. WordCraft runs `espeak-ng ... --stdin` and writes the text to standard input.
3. The adapter:
   - in online mode, generates an MP3 with `edge-tts` and plays it;
   - in offline mode, generates a WAV with Piper (or MBROLA) and plays it;
   - if the online voice fails, uses the offline voice;
   - if the offline voice fails or takes too long, tries MBROLA es3 if installed;
   - as a last resort, uses `spd-say` with a female voice.
4. Sentences are cached by text, voice, and speed so they are not regenerated.
5. If another app calls `espeak-ng` without `--stdin`, the adapter forwards the call to the real `espeak-ng`. If it does not exist, it prints an error and does not break WordCraft.

The installer saves the previous `espeak-ng` as `~/.local/bin/espeak-ng.voz-wordcraft-backup` and restores it on uninstall.

## Privacy

- **Online:** the text is sent to Microsoft's servers (Edge TTS) to generate the audio.
- **Offline:** everything is generated on your machine with Piper or MBROLA; no text is sent to the internet.
- The local cache stores generated audio in `~/.cache/voz-wordcraft/`. You can clear it with `voz-wordcraft limpiar`.
- The log `~/.cache/voz-wordcraft/voz.log` stores metadata (voice, speed, text length), not the full text.

## Performance

Measured on an Intel Celeron 3855U (2 cores), approximate:

| Voice | Short sentence | Long sentence |
| --- | --- | --- |
| Sharvard F (Piper) | ~5.5 s | ~30 s |
| Daniela (Piper) | ~16-20 s | ~30-40 s |
| MBROLA es3 | < 0.3 s | ~1 s |
| Dalia (online) | +1-3 s network | +1-3 s network |

The first sentence with each voice may take longer while the model loads. If you use Daniela on a slow machine, raise `TIEMPO_MAX_OFFLINE` in the configuration (for example, to `120`). If you prefer the fast backup to kick in sooner, lower it.

## Troubleshooting

**`voz-wordcraft: command not found`**

Add `~/.local/bin` to `PATH` and log in again:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
source ~/.profile
```

Or run the command with its full path: `~/.local/bin/voz-wordcraft`.

**WordCraft still uses a robotic voice**

Check that the adapter comes first in `PATH`:

```bash
command -v espeak-ng
# It should print /home/YOUR_USER/.local/bin/espeak-ng
```

If WordCraft was already open, close and reopen it. Restarting the session can also help.

**No sound**

Install a player and test:

```bash
sudo apt install ffmpeg
voz-wordcraft probar SharvardF
```

**The online voice does not work**

Check the internet connection and run the diagnostics:

```bash
voz-wordcraft diagnostico
voz-wordcraft online
```

If there is no internet, online mode uses the offline voice automatically. To force the local voice: `voz-wordcraft offline`.

**The offline voice is too slow**

Sharvard F is the fastest. Daniela is more natural but slow. MBROLA is almost instant, although it sounds robotic:

```bash
./install.sh --with-mbrola
voz-wordcraft usar MBROLA
```

You can also adjust `TIEMPO_MAX_OFFLINE` in `~/.config/voz-wordcraft/config`.

**MBROLA does not install**

MBROLA is only automated on Debian/Ubuntu/Kali. It needs `apt-get`, `dpkg-deb`, `libespeak-ng1`, and `espeak-ng` data. The installer can download the binary and data, but it does not install system libraries with `sudo`.

**I want to see what happened**

```bash
tail -n 50 ~/.cache/voz-wordcraft/voz.log
```

## Uninstall

```bash
./uninstall.sh
```

It keeps the configuration for a future reinstall. To also remove the configuration:

```bash
./uninstall.sh --purge
```

You can also use `./install.sh --uninstall` or `./install.sh --uninstall --purge`.

The uninstaller removes the commands, adapter, Piper, downloaded voices, MBROLA, and cache, and restores the previous `espeak-ng` if there was one.

## Tests

```bash
./tests/run.sh
```

The tests do not use the network, do not download voices, and do not touch the real installation: they use a temporary `HOME` and simulated Edge TTS, Piper, and network.

## License

The scripts in this project are released under the **MIT** license (see [LICENSE](LICENSE)). Third-party voices, binaries, and services have their own licenses and are **not included in the repository**; they are downloaded during installation. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

WordCraft is an independent project. This repository is not affiliated with WordCraft or Microsoft.
