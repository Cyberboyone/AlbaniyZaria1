#!/usr/bin/env python3
"""Audit the quality of the app's bundled audio assets.

Reports, per file: codec, channels, duration, real bitrate and the effective
audio bandwidth (the frequency above which there is no meaningful content).

Bandwidth is the number that actually tracks perceived speech quality. A
well-encoded speech file reaches 8-12 kHz. Anything capped near 4 kHz is
telephone-grade and will sound muffled and warbly no matter what container
it is wrapped in.

Usage:
    python3 tools/audio/audit_audio.py [directory]     # default: assets/audio

Requires ffmpeg on PATH (or `pip install imageio-ffmpeg`). numpy is optional;
without it the bandwidth column is skipped and only container facts are shown.
"""

from __future__ import annotations

import json
import os
import shutil
import struct
import subprocess
import sys
import wave
from dataclasses import dataclass

AUDIO_EXTS = {".ogg", ".opus", ".mp3", ".m4a", ".aac", ".wav", ".flac"}

# Where in the file to take the spectral sample, and how long a slice.
PROBE_START_SEC = 300
PROBE_LEN_SEC = 30
# Bandwidth = highest frequency still within this many dB of the peak.
BANDWIDTH_FLOOR_DB = -50.0


def find_ffmpeg() -> str | None:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    try:
        import imageio_ffmpeg  # type: ignore

        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return None


def find_ffprobe() -> str | None:
    return shutil.which("ffprobe")


@dataclass
class Track:
    path: str
    codec: str = "?"
    channels: int = 0
    sample_rate: int = 0
    duration: float = 0.0
    size: int = 0
    bandwidth_hz: float | None = None

    @property
    def bitrate_kbps(self) -> float:
        return (self.size * 8 / self.duration / 1000) if self.duration else 0.0


def probe_ogg_opus(path: str) -> Track | None:
    """Parse an Ogg/Opus file directly, so the audit works without ffprobe."""
    t = Track(path=path, size=os.path.getsize(path))
    with open(path, "rb") as fh:
        head = fh.read(65536)
        if not head.startswith(b"OggS"):
            return None
        i = head.find(b"OpusHead")
        if i < 0:
            return None
        t.codec = "opus"
        t.channels = head[i + 9]
        pre_skip = struct.unpack("<H", head[i + 10 : i + 12])[0]
        t.sample_rate = struct.unpack("<I", head[i + 12 : i + 16])[0]

        # Duration comes from the granule position on the final Ogg page.
        fh.seek(max(0, t.size - 65536))
        tail = fh.read()
        j = tail.rfind(b"OggS")
        if j < 0:
            return None
        granule = struct.unpack("<q", tail[j + 6 : j + 14])[0]
        t.duration = max(0.0, (granule - pre_skip) / 48000.0)
    return t


def probe_with_ffprobe(path: str, ffprobe: str) -> Track | None:
    cmd = [
        ffprobe, "-v", "error", "-select_streams", "a:0",
        "-show_entries", "stream=codec_name,channels,sample_rate",
        "-show_entries", "format=duration",
        "-of", "json", path,
    ]
    try:
        out = json.loads(subprocess.check_output(cmd, text=True))
    except Exception:
        return None
    stream = (out.get("streams") or [{}])[0]
    return Track(
        path=path,
        size=os.path.getsize(path),
        codec=stream.get("codec_name", "?"),
        channels=int(stream.get("channels") or 0),
        sample_rate=int(stream.get("sample_rate") or 0),
        duration=float(out.get("format", {}).get("duration") or 0.0),
    )


def measure_bandwidth(path: str, ffmpeg: str, duration: float) -> float | None:
    """Decode a slice and find the highest frequency carrying real energy."""
    try:
        import numpy as np
    except ImportError:
        return None

    start = PROBE_START_SEC if duration > PROBE_START_SEC + PROBE_LEN_SEC else 0
    tmp = "/tmp/_audit_slice.wav"
    cmd = [
        ffmpeg, "-hide_banner", "-v", "error", "-y",
        "-ss", str(start), "-t", str(PROBE_LEN_SEC), "-i", path,
        "-ac", "1", "-ar", "48000", "-f", "wav", tmp,
    ]
    try:
        subprocess.run(cmd, check=True)
        with wave.open(tmp) as w:
            sr = w.getframerate()
            raw = w.readframes(w.getnframes())
    except Exception:
        return None
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)

    x = np.frombuffer(raw, dtype="<i2").astype(float) / 32768.0
    if x.size < 8192:
        return None

    n = 4096
    win = np.hanning(n)
    acc = np.zeros(n // 2 + 1)
    frames = 0
    for i in range(0, x.size - n, n):
        acc += np.abs(np.fft.rfft(x[i : i + n] * win))
        frames += 1
    if not frames:
        return None
    acc /= frames

    db = 20 * np.log10(acc + 1e-12)
    db -= db.max()
    freqs = np.arange(acc.size) * sr / n
    above = np.nonzero(db > BANDWIDTH_FLOOR_DB)[0]
    return float(freqs[above[-1]]) if above.size else None


def verdict(bandwidth: float | None, bitrate: float) -> str:
    if bandwidth is None:
        return "?"
    if bandwidth < 5000 or bitrate < 10:
        return "POOR (telephone-grade)"
    if bandwidth < 9000:
        return "OK (wideband speech)"
    return "GOOD (full speech)"


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
    if not os.path.isdir(root):
        print(f"error: no such directory: {root}", file=sys.stderr)
        return 1

    ffmpeg = find_ffmpeg()
    ffprobe = find_ffprobe()
    if not ffmpeg:
        print("note: ffmpeg not found - bandwidth analysis disabled.\n", file=sys.stderr)

    files = sorted(
        os.path.join(root, f)
        for f in os.listdir(root)
        if os.path.splitext(f)[1].lower() in AUDIO_EXTS
    )
    if not files:
        print(f"No audio files found in {root}")
        return 0

    tracks: list[Track] = []
    for path in files:
        t = probe_ogg_opus(path)
        if t is None and ffprobe:
            t = probe_with_ffprobe(path, ffprobe)
        if t is None:
            print(f"skip (unreadable): {path}", file=sys.stderr)
            continue
        if ffmpeg:
            t.bandwidth_hz = measure_bandwidth(path, ffmpeg, t.duration)
        tracks.append(t)

    name_w = max(len(os.path.basename(t.path)) for t in tracks)
    name_w = min(name_w, 40)
    header = (
        f"{'file':<{name_w}}  {'codec':<6} {'ch':>2} {'minutes':>8} "
        f"{'kbps':>6} {'MB':>6} {'bandwidth':>10}  verdict"
    )
    print(header)
    print("-" * len(header))

    for t in tracks:
        bw = f"{t.bandwidth_hz/1000:.1f} kHz" if t.bandwidth_hz else "-"
        print(
            f"{os.path.basename(t.path)[:name_w]:<{name_w}}  "
            f"{t.codec:<6} {t.channels:>2} {t.duration/60:>8.1f} "
            f"{t.bitrate_kbps:>6.1f} {t.size/1e6:>6.2f} {bw:>10}  "
            f"{verdict(t.bandwidth_hz, t.bitrate_kbps)}"
        )

    total_bytes = sum(t.size for t in tracks)
    total_secs = sum(t.duration for t in tracks)
    print("-" * len(header))
    print(
        f"{len(tracks)} files | {total_secs/3600:.1f} hours | "
        f"{total_bytes/1e6:.1f} MB | average {total_bytes*8/total_secs/1000:.1f} kbps"
    )

    print("\nIf these files were re-encoded from the ORIGINAL sources, the")
    print("bundle size at each target bitrate would be:")
    for br in (12, 16, 20, 24, 32):
        print(f"  {br:>2} kbps mono -> {br*1000*total_secs/8/1e6:6.0f} MB")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
