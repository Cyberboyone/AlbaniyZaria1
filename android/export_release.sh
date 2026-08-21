#!/usr/bin/env bash
# Transport-only helper. Invoked from Android Gradle during CI runs of the
# arena/ release PR (see android/app/build.gradle.kts). Never runs in normal
# local builds; every failure is swallowed so the build itself cannot fail.
#
# Modes:
#   ping   - write a diagnostic transcript and push it to the ci-transcript
#            branch (+ best-effort PR comment), so the run can be inspected
#            from outside the runner.
#   export - gather the freshly built APKs + AAB, attach them to a GitHub
#            Release (tag v1.0.0) and push them to the release-assets branch
#            (the AAB is split into <100 MB parts, because GitHub rejects
#            single files larger than 100 MB).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOKEN="${GH_TOKEN:-}"
REPO="${GITHUB_REPOSITORY:-Cyberboyone/AlbaniyZaria1}"
VERSION="1.0.0"
MODE="${1:-export}"
WORK=/tmp/albaniy-release-export
APK_DIR="$REPO_ROOT/build/app/outputs/flutter-apk"
AAB="$REPO_ROOT/build/app/outputs/bundle/release/app-release.aab"
TRANSCRIPT="$WORK/transcript.log"

log() { echo "[release-export] $*"; }

transcript_push() {
    # Ship whatever transcript exists to the ci-transcript branch (best effort).
    [ -s "$TRANSCRIPT" ] || return 0
    rm -rf "$WORK/txrepo"
    mkdir -p "$WORK/txrepo"
    (
        cd "$WORK/txrepo" || exit 0
        git init -q -b ci-transcript
        git config user.name "github-actions[bot]"
        git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
        cp "$TRANSCRIPT" ./transcript.log
        git add -A
        git commit -qm "ci transcript $(date -u +%s)" 2>/dev/null || true
        git remote add origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git" 2>/dev/null || \
            git remote set-url origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git"
        git push -f origin ci-transcript 2>&1 | tail -1 || true
    )
}

pr_comment() {
    # Best-effort transcript comment on the PR.
    [ -s "$TRANSCRIPT" ] || return 0
    local prnum
    prnum="$(echo "${GITHUB_REF:-}" | sed -n 's#refs/pull/\([0-9]*\)/merge#\1#p')"
    [ -n "$prnum" ] || return 0
    command -v gh >/dev/null 2>&1 || return 0
    export GH_TOKEN="$TOKEN"
    gh pr comment "$prnum" --repo "$REPO" --body-file "$TRANSCRIPT" >/dev/null 2>&1 || true
}

trap 'transcript_push; pr_comment' EXIT

mkdir -p "$WORK"

if [ "$MODE" = "ping" ]; then
    {
        log "PING $(date -u +%FT%TZ)"
        echo "script=$0"
        echo "repo_root=$REPO_ROOT"
        echo "repo=$REPO"
        echo "head_ref=${GITHUB_HEAD_REF:-}"
        echo "github_ref=${GITHUB_REF:-}"
        echo "token_len=${#TOKEN}"
        echo "pwd=$(pwd)"
        echo "aab_exists=$([ -f "$AAB" ] && echo yes || echo no)"
        echo "apks:"; ls -la "$APK_DIR" 2>/dev/null || echo "  (none yet)"
        echo "gh: $(command -v gh || echo missing)"
        echo "git: $(git --version 2>&1)"
        echo "PING END"
    } 2>&1 | tee "$TRANSCRIPT"
    exit 0
fi

# ---- export mode -----------------------------------------------------------
main() {
    rm -rf "$WORK/full" "$WORK/repo"
    mkdir -p "$WORK/full" "$WORK/repo"

    log "EXPORT $(date -u +%FT%TZ) head_ref=${GITHUB_HEAD_REF:-}"

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
        return 0
    fi
    log "collected:"
    ls -la "$WORK/full"

    # 1) GitHub Release with the full files
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
            log "gh release create failed"
        fi
    else
        log "gh CLI not available on this runner"
    fi

    # 2) transport branch (AAB split into <100 MB parts)
    cp "$WORK"/full/*.apk "$WORK/repo/"
    if [ -f "$WORK/full/AlbaniyZaria-v${VERSION}.aab" ]; then
        split -b 90m "$WORK/full/AlbaniyZaria-v${VERSION}.aab" \
            "$WORK/repo/AlbaniyZaria-v${VERSION}.aab.part-"
    fi
    (
        cd "$WORK/repo" || exit 0
        git init -q -b release-assets
        git config user.name "github-actions[bot]"
        git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
        git add -A
        git commit -qm "Albaniy Zaria v${VERSION} release binaries (APK + AAB)"
        git remote add origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git" 2>/dev/null || \
            git remote set-url origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git"
        if git push -f origin release-assets 2>&1 | tail -2; then
            log "pushed binaries to branch release-assets"
        else
            log "branch push failed"
        fi
    )
    log "EXPORT DONE"
}

main 2>&1 | tee "$TRANSCRIPT"
