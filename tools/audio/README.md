# Audio quality: findings and options

_Audit performed 2026-08-28 against the 20 files in `assets/audio/`._

## TL;DR

The bundled audio does not sound bad because it is `.ogg`. It sounds bad
because it was encoded at **~6.5 kbps**, which band-limits it to roughly
**4 kHz** — below telephone quality.

**Converting the current files to another format cannot fix this.** Opus is
already the best codec available at low bitrates; MP3, AAC or Vorbis at the
same size would sound clearly *worse*. And every re-encode of an already-lossy
file adds a second generation of loss on top. The only real fix is to
re-encode **from the original sources** at a higher bitrate.

## What was measured

Run it yourself:

```bash
python3 tools/audio/audit_audio.py
```

```
20 files | 28.1 hours | 83.2 MB | average 6.6 kbps
```

Every file reports the same verdict:

| Property | Value |
| --- | --- |
| Container | Ogg |
| Codec | **Opus** (not Vorbis — the assumption in the issue was wrong) |
| Channels | Mono |
| Bitrate | **6.0 – 7.6 kbps** |
| Audio bandwidth | **4.0 – 4.9 kHz** |
| Encoder tag | `Lavc63.7.100 libopus`, sources were 16 kHz |

Spectral analysis of `01. Matasa.ogg` shows the cliff clearly — energy
collapses right after 4 kHz, which is where the consonants that carry speech
intelligibility live:

```
 1000 Hz:  -16.4 dB
 2000 Hz:  -23.5 dB
 3000 Hz:  -25.4 dB
 4000 Hz:  -38.5 dB   <- rolloff begins
 5000 Hz:  -56.0 dB   <- effectively nothing above here
 8000 Hz:  -65.2 dB
```

At 6.5 kbps, Opus's SILK layer is starved of bits. That is the warbly,
underwater, "robotic" character you can hear.

## The real constraint

The app bundles **28.1 hours** of speech for offline playback. That is a lot
of audio, and it is why someone reached for 6.5 kbps in the first place.

| Bitrate | Total size | Quality |
| --- | --- | --- |
| 6.5 kbps | **82 MB** | current — poor, ~4 kHz |
| 12 kbps | 152 MB | noticeably better, ~6 kHz |
| 16 kbps | 202 MB | good wideband speech, ~8 kHz |
| 20 kbps | 253 MB | very good |
| 24 kbps | 303 MB | transparent for speech |
| 32 kbps | 404 MB | overkill for mono speech |

Google Play caps the download size of the base + config APKs at **200 MB**.
So anything above ~12 kbps cannot ship inside the app bundle as it is
structured today.

## Options

### A. Re-encode from originals at 12 kbps, keep everything bundled
Roughly doubles the bitrate and lifts the bandwidth to ~6 kHz. Audibly better
than today, still compromised, and no architectural change is needed.
Lands around 152 MB, which is uncomfortably close to the Play limit once the
Flutter engine and ads SDK are counted.

### B. Move audio out of the bundle (recommended if quality is the priority)
Ship a small APK and fetch lectures on first play, caching them on device.
This removes the size ceiling entirely and allows 24 kbps or better. Requires
hosting (any CDN or object store) plus download/caching code in Dart.

### C. Play Asset Delivery
Google's official mechanism for large assets, free hosting up to 2 GB.
Unlocks high bitrate without your own CDN, but is Android-only and needs
build configuration work.

In all three cases the **original MP3s are required**. They are not in this
repository and never were — `git log --all` across the full history shows only
these 20 `.ogg` files.

## Tooling in this directory

| File | Purpose |
| --- | --- |
| `audit_audio.py` | Measures codec, bitrate and true audio bandwidth of any audio directory. Use it to verify results after re-encoding. |
| `reencode.sh` | Re-encodes original sources to speech-tuned Opus at a chosen bitrate. |

### Re-encoding, once the originals are available

```bash
# preview
DRY_RUN=1 tools/audio/reencode.sh ~/originals assets/audio 16

# do it, and even out the volume differences between lectures
NORMALIZE=1 tools/audio/reencode.sh ~/originals assets/audio 16

# confirm the result
python3 tools/audio/audit_audio.py assets/audio
```

The encoder settings are tuned for spoken lectures rather than music:
`-vbr on` spends bits on speech and almost nothing on silence,
`-frame_duration 60` cuts packet overhead by 5–8 % at these bitrates (safe
because playback is non-interactive), `-compression_level 10` uses the
encoder's maximum search effort, and `-application audio` keeps the voice
natural instead of the more aggressive `voip` processing.

`reencode.sh` refuses to run if the sources are themselves below 12 kbps, to
stop the current files being fed back into it by accident.

## Note on the release pipeline

Nothing in this audit touches `.github/workflows/build.yml`, the signing
configuration, or `android/key.properties`. Re-encoding only replaces files
inside `assets/audio/`, which the existing build picks up automatically via
the `assets/audio/` entry in `pubspec.yaml`.

If a re-encode changes any **filenames**, update the `audioAssetPath` values in
`lib/data/sample_lessons.dart` to match — those paths are hardcoded, and a
mismatch fails at runtime rather than at build time.
