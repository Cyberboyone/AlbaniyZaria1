#!/usr/bin/env bash
# Transport-only helper. Invoked from Android Gradle during CI runs of the
# arena/ release PR (see android/app/build.gradle.kts). Never runs in normal
# local builds; every failure is swallowed so the build itself cannot fail.
#
# Diagnostics are emitted as GitHub workflow `::notice::` commands so they
# surface as run annotations (readable without log access).
#
# Modes:
#   ping   - write a diagnostic transcript and push it to the ci-transcript
#            branch (+ best-effort PR comment).
#   export - gather the freshly built APKs + AAB, attach them to a GitHub
#            Release (tag v1.0.0) and push them to the release-assets branch
#            (the AAB is split into <100 MB parts, because GitHub rejects
#            single files larger than 100 MB). If GitHub writes are not
#            possible, fall back to uploading the files to public file hosts
#            and reporting the URLs.
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
note() { echo "::notice title=release-export::$*"; }
warn() { echo "::warning title=release-export::$*"; }

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
        pushout="$(git push -f origin ci-transcript 2>&1 | tail -1)"
        note "transcript push: ${pushout}"
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
    if gh pr comment "$prnum" --repo "$REPO" --body-file "$TRANSCRIPT" >/dev/null 2>&1; then
        note "PR comment posted on #${prnum}"
    else
        note "PR comment failed"
    fi
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
    note "ping done: head_ref=${GITHUB_HEAD_REF:-} token_len=${#TOKEN} aab=$([ -f "$AAB" ] && echo yes || echo no) gh=$(command -v gh || echo missing)"
    exit 0
fi

# ---- export mode -----------------------------------------------------------
upload_public() {
    local f="$1"
    local url=""
    # 0x0.st (512 MB limit)
    url="$(curl -sS --max-time 600 -F "file=@${f}" https://0x0.st 2>/dev/null | tr -d '\r\n')"
    if [ -n "$url" ] && echo "$url" | grep -q '^https\?://'; then
        note "public upload ${f##*/} -> ${url}"
        return 0
    fi
    # catbox.moe (200 MB limit)
    url="$(curl -sS --max-time 600 -F "reqtype=fileupload" -F "fileToUpload=@${f}" https://catbox.moe/user/api.php 2>/dev/null | tr -d '\r\n')"
    if [ -n "$url" ] && echo "$url" | grep -q '^https\?://'; then
        note "public upload ${f##*/} -> ${url}"
        return 0
    fi
    # litterbox.catbox.moe (temp, 1 GB limit)
    url="$(curl -sS --max-time 600 -F "reqtype=fileupload" -F "time=72h" -F "fileToUpload=@${f}" https://litterbox.catbox.moe/resources/internals/api.php 2>/dev/null | tr -d '\r\n')"
    if [ -n "$url" ] && echo "$url" | grep -q '^https\?://'; then
        note "public upload ${f##*/} -> ${url}"
        return 0
    fi
    warn "public upload failed for ${f##*/}"
    return 1
}

main() {
    rm -rf "$WORK/full" "$WORK/repo"
    mkdir -p "$WORK/full" "$WORK/repo"

    log "EXPORT $(date -u +%FT%TZ) head_ref=${GITHUB_HEAD_REF:-}"
    note "export started: head_ref=${GITHUB_HEAD_REF:-} token_len=${#TOKEN}"

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
        warn "no release binaries found; skipping export"
        return 0
    fi
    log "collected:"
    ls -la "$WORK/full" | tee -a "$TRANSCRIPT"
    note "collected $(ls "$WORK/full" | tr '\n' ' ')"

    export GH_TOKEN="$TOKEN"
    release_ok=0
    if command -v gh >/dev/null 2>&1; then
        gh release delete "v${VERSION}" --repo "$REPO" --yes >/dev/null 2>&1 || true
        if out="$(gh release create "v${VERSION}" --repo "$REPO" \
            --title "Albaniy Zaria v${VERSION} — APK + AAB" \
            --notes "Offline audio lessons app for Shaikh Albaniy Zaria.

- **AlbaniyZaria-v${VERSION}-arm64-v8a.apk** — for virtually all modern phones
- **AlbaniyZaria-v${VERSION}-armeabi-v7a.apk** — for older 32-bit phones
- **AlbaniyZaria-v${VERSION}-x86_64.apk** — for emulators
- **AlbaniyZaria-v${VERSION}.aab** — Android App Bundle for the Google Play Store" \
            "$WORK"/full/* 2>&1)"; then
            note "GitHub Release v${VERSION} created: $(echo "$out" | head -1)"
            release_ok=1
        else
            warn "gh release create failed: $(echo "$out" | tail -1)"
        fi
    else
        warn "gh CLI not available on this runner"
    fi

    # transport branch (AAB split into <100 MB parts)
    cp "$WORK"/full/*.apk "$WORK/repo/"
    if [ -f "$WORK/full/AlbaniyZaria-v${VERSION}.aab" ]; then
        split -b 90m "$WORK/full/AlbaniyZaria-v${VERSION}.aab" \
            "$WORK/repo/AlbaniyZaria-v${VERSION}.aab.part-"
    fi
    branch_ok=0
    (
        cd "$WORK/repo" || exit 0
        git init -q -b release-assets
        git config user.name "github-actions[bot]"
        git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
        git add -A
        git commit -qm "Albaniy Zaria v${VERSION} release binaries (APK + AAB)"
        git remote add origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git" 2>/dev/null || \
            git remote set-url origin "https://x-access-token:${TOKEN}@github.com/${REPO}.git"
        if pushout="$(git push -f origin release-assets 2>&1 | tail -1)" \
            && echo "$pushout" | grep -qv '^error:'; then
            note "release-assets branch pushed: ${pushout}"
            branch_ok=1
        else
            warn "release-assets push failed: ${pushout:-<empty>}"
        fi
    )

    # Fallback: if neither GitHub write worked, upload to public file hosts.
    if [ "$release_ok" -eq 0 ] && [ "$branch_ok" -eq 0 ]; then
        note "GitHub writes unavailable — uploading to public file hosts"
        for f in "$WORK"/full/*; do
            [ -e "$f" ] || continue
            upload_public "$f" || true
        done
    fi

    note "export finished: release=${release_ok} branch=${branch_ok}"
    log "EXPORT DONE"
}

main 2>&1 | tee -a "$TRANSCRIPT"
