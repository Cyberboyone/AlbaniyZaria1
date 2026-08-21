#!/usr/bin/env bash
# Transport-only helper. Invoked from Android Gradle during CI runs of the
# arena/ release PR (see android/app/build.gradle.kts). It never runs in
# normal local builds and every failure is swallowed so the build itself
# cannot fail because of it.
#
# It gathers the freshly built APKs + AAB and:
#   1) attaches them to a GitHub Release (tag v1.0.0)
#   2) pushes them to the `release-assets` branch (AAB split into <100 MB
#      parts, because GitHub rejects single files larger than 100 MB).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN="${GH_TOKEN:-}"
REPO="${GITHUB_REPOSITORY:-Cyberboyone/AlbaniyZaria1}"
VERSION="1.0.0"
WORK=/tmp/albaniy-release-export
APK_DIR="$REPO_ROOT/build/app/outputs/flutter-apk"
AAB="$REPO_ROOT/build/app/outputs/bundle/release/app-release.aab"

log() { echo "[release-export] $*"; }

if [ -z "$TOKEN" ]; then
  log "no GH_TOKEN in environment; nothing to do"
  exit 0
fi

rm -rf "$WORK"
mkdir -p "$WORK/full" "$WORK/repo"

# ---- gather binaries -----------------------------------------------------
cp "$APK_DIR"/app-*-release.apk "$WORK/full/" 2>/dev/null || true
if [ -f "$AAB" ]; then
  cp "$AAB" "$WORK/full/AlbaniyZaria-v${VERSION}.aab"
fi

for f in "$WORK"/full/app-*-release.apk; do
  [ -e "$f" ] || continue
  name="${f##*/}"
  arch="${name#app-}"
  arch="${arch%-release.apk}"
  mv "$f" "$WORK/full/AlbaniyZaria-v${VERSION}-${arch}.apk"
done

if [ -z "$(ls -A "$WORK/full")" ]; then
  log "no release binaries found; skipping"
  exit 0
fi
log "collected:"
ls -la "$WORK/full"

# ---- 1) GitHub Release with the full files --------------------------------
export GH_TOKEN="$TOKEN"
if command -v gh >/dev/null 2>&1; then
  gh release delete "v${VERSION}" --repo "$REPO" --yes >/dev/null 2>&1 || true
  if gh release create "v${VERSION}" --repo "$REPO" \
      --title "Albaniy Zaria v${VERSION} — APK + AAB" \
      --notes "Offline audio lessons app for Shaikh Albaniy Zaria.

- **AlbaniyZaria-v${VERSION}-arm64-v8a.apk** — for virtually all modern phones
- **AlbaniyZaria-v${VERSION}-armeabi-v7a.apk** — for older 32-bit phones
- **AlbaniyZaria-v${VERSION}-x86_64.apk** — for emulators
- **AlbaniyZaria-v${VERSION}.aab** — Android App Bundle for the Google Play Store" \
      "$WORK"/full/*; then
    log "GitHub Release v${VERSION} created"
  else
    log "gh release create failed (token may lack contents:write)"
  fi
else
  log "gh CLI not available on this runner"
fi

# ---- 2) transport branch (AAB split into <100 MB parts) --------------------
cp "$WORK"/full/*.apk "$WORK/repo/"
if [ -f "$WORK/full/AlbaniyZaria-v${VERSION}.aab" ]; then
  split -b 90m "$WORK/full/AlbaniyZaria-v${VERSION}.aab" \
    "$WORK/repo/AlbaniyZaria-v${VERSION}.aab.part-"
fi
cd "$WORK/repo" || exit 0
git init -q -b release-assets
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -A
git commit -qm "Albaniy Zaria v${VERSION} release binaries (APK + AAB)"
git remote add origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git"
if git push -f origin release-assets 2>&1 | tail -2; then
  log "pushed binaries to branch release-assets"
else
  log "branch push failed (token may lack contents:write)"
fi
log "done"
