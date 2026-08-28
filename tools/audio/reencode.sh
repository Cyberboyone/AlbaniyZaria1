#!/usr/bin/env bash
#
# Re-encode ORIGINAL lecture audio into speech-tuned Opus for the app bundle.
#
# Read tools/audio/README.md first. In short: the audio currently shipped in
# assets/audio/ is Opus at ~6.5 kbps, band-limited to ~4 kHz. That is the cause
# of the poor quality, not the .ogg container. Running this script on those
# files will NOT help - it only adds a second generation of loss. Point it at
# the original MP3s.
#
# Usage:
#   tools/audio/reencode.sh <source-dir> <output-dir> [bitrate-kbps]
#
# Example:
#   tools/audio/reencode.sh ~/originals assets/audio 16
#
# Environment overrides:
#   APPLICATION=audio|voip   libopus tuning        (default: audio)
#   JOBS=<n>                 parallel encodes      (default: CPU count)
#   NORMALIZE=1              even out loudness across lectures (slower, 2-pass)
#   FORCE=1                  skip the low-bitrate-source safety check
#   DRY_RUN=1                print what would happen, encode nothing
#
set -euo pipefail

SRC=${1:-}
OUT=${2:-}
BITRATE=${3:-16}

APPLICATION=${APPLICATION:-audio}
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}
NORMALIZE=${NORMALIZE:-0}
FORCE=${FORCE:-0}
DRY_RUN=${DRY_RUN:-0}

if [[ -z $SRC || -z $OUT ]]; then
  awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "error: ffmpeg is required but not on PATH." >&2
  echo "       macOS: brew install ffmpeg | Ubuntu: sudo apt install ffmpeg" >&2
  exit 1
fi

[[ -d $SRC ]] || { echo "error: source dir not found: $SRC" >&2; exit 1; }
mkdir -p "$OUT"

# --- Why these flags -------------------------------------------------------
# -c:a libopus        best-in-class codec for speech at low bitrates
# -vbr on             variable bitrate; spends bits on speech, saves on silence
# -compression_level 10  maximum encoder search effort (slower, smaller/better)
# -frame_duration 60  60 ms frames cut per-packet overhead ~5-8% at these
#                     bitrates. Safe here because playback is non-interactive.
# -application audio  keeps voices natural; 'voip' is more aggressive/robotic
# -ac 1               source lectures are mono; stereo would double the cost
# -ar 48000           Opus's native clock; avoids a resample at playback time
# -vn -map_metadata 0 drop embedded cover art, keep tags
OPUS_ARGS=(
  -c:a libopus
  -b:a "${BITRATE}k"
  -vbr on
  -compression_level 10
  -frame_duration 60
  -application "$APPLICATION"
  -ac 1
  -ar 48000
  -vn
  -map_metadata 0
)

encode_one() {
  local in=$1 out=$2 bitrate=$3 normalize=$4
  shift 4
  local -a args=("$@")

  if [[ $normalize == 1 ]]; then
    # EBU R128 to -16 LUFS: makes every lecture sit at the same volume, so
    # listeners stop riding the volume slider between tracks.
    ffmpeg -hide_banner -v error -y -i "$in" \
      -af loudnorm=I=-16:TP=-1.5:LRA=11 "${args[@]}" "$out"
  else
    ffmpeg -hide_banner -v error -y -i "$in" "${args[@]}" "$out"
  fi
}
export -f encode_one

# --- Safety: refuse to transcode already-starved sources -------------------
if [[ $FORCE != 1 ]] && command -v ffprobe >/dev/null 2>&1; then
  low=0
  while IFS= read -r -d '' f; do
    br=$(ffprobe -v error -select_streams a:0 -show_entries \
         format=bit_rate -of csv=p=0 "$f" 2>/dev/null || echo 0)
    [[ -n $br && $br != N/A && $br -lt 12000 ]] && low=$((low + 1))
  done < <(find "$SRC" -maxdepth 1 -type f \
           \( -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.wav' \
              -o -iname '*.flac' -o -iname '*.ogg' -o -iname '*.opus' \) -print0)
  if (( low > 0 )); then
    cat >&2 <<EOF
error: $low source file(s) are already below 12 kbps.

  Re-encoding them cannot restore quality - it only adds another generation
  of loss. You almost certainly want the ORIGINAL MP3s here instead.

  If you really mean it, re-run with FORCE=1.
EOF
    exit 1
  fi
fi

echo "source      : $SRC"
echo "output      : $OUT"
echo "bitrate     : ${BITRATE} kbps mono Opus (application=$APPLICATION)"
echo "normalize   : $([[ $NORMALIZE == 1 ]] && echo 'yes (-16 LUFS)' || echo no)"
echo "parallelism : $JOBS"
echo

sources=()
while IFS= read -r -d '' f; do
  sources+=("$f")
done < <(find "$SRC" -maxdepth 1 -type f \
         \( -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.wav' \
            -o -iname '*.flac' -o -iname '*.aac' \) -print0 | sort -z)

if (( ${#sources[@]} == 0 )); then
  echo "error: no source audio (.mp3/.m4a/.wav/.flac/.aac) found in $SRC" >&2
  exit 1
fi

if [[ $DRY_RUN == 1 ]]; then
  for f in "${sources[@]}"; do
    base=$(basename "$f")
    echo "would encode: $base -> ${base%.*}.ogg"
  done
  echo
  echo "${#sources[@]} file(s) would be encoded. Re-run without DRY_RUN=1 to do it."
  exit 0
fi

for f in "${sources[@]}"; do
  base=$(basename "$f")
  printf '%s\0%s\0' "$f" "$OUT/${base%.*}.ogg"
done | xargs -0 -n2 -P "$JOBS" bash -c \
    'echo "encoding: $(basename "$0")"; \
     encode_one "$0" "$1" '"$BITRATE $NORMALIZE"' '"${OPUS_ARGS[*]}"

echo
echo "Done. Verifying output:"
python3 "$(dirname "$0")/audit_audio.py" "$OUT" || true

cat <<EOF

Next steps:
  1. Listen to a couple of files end to end before committing.
  2. Check the total size against your delivery budget.
  3. If filenames changed, update lib/data/sample_lessons.dart to match.
EOF
