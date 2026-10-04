#!/bin/bash
# Add the .rpm assets of OTP releases to the yum repositories.
# Only the repodata is kept in REPO_DIR (rpm/ on gh-pages); package
# locations point at the GitHub release assets.
#
# Usage: ./rpm-index.sh [--rebuild] REPO_DIR VERSION...
#   --rebuild  drop the existing repodata and index only VERSION...
#
# Requires: gh (authenticated), createrepo_c

set -euo pipefail

REBUILD=0
if [ "${1:-}" = "--rebuild" ]; then
    REBUILD=1
    shift
fi

REPO_DIR="${1:?Repository directory required}"
shift
[ $# -gt 0 ] || { echo "No version given"; exit 1; }

GH_REPO="${GH_REPO:-${GITHUB_REPOSITORY:?GH_REPO or GITHUB_REPOSITORY required}}"
export GH_REPO
BASEURL="https://github.com/${GH_REPO}/releases/download/"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

DISTROS="rocky9 cs9 cs10"
ARCHS="x86_64 aarch64"

decompress() {
    case "$1" in
        *.zst) zstd -dcq "$1" ;;
        *.xz) xzcat "$1" ;;
        *.gz) zcat "$1" ;;
        *) cat "$1" ;;
    esac
}

# Recreate each release asset as an empty file so createrepo_c reuses its
# cached metadata (--skip-stat) without downloading it again.
for DISTRO in $DISTROS; do
    for ARCH in $ARCHS; do
        DIR="$STAGE/$DISTRO/$ARCH"
        mkdir -p "$DIR"
        OLD="$REPO_DIR/$DISTRO/$ARCH/repodata"
        [ "$REBUILD" = 0 ] && [ -f "$OLD/repomd.xml" ] || continue
        cp -r "$OLD" "$DIR/"
        PRIMARY=$(grep -o 'href="repodata/[^"]*primary\.xml[^"]*"' "$OLD/repomd.xml" | cut -d'"' -f2)
        { decompress "$REPO_DIR/$DISTRO/$ARCH/$PRIMARY" | grep -o 'href="OTP-[^"]*\.rpm"' || true; } | cut -d'"' -f2 |
            while read -r HREF; do
                mkdir -p "$DIR/$(dirname "$HREF")"
                : > "$DIR/$HREF"
            done
    done
done

for VERSION in "$@"; do
    TAG="OTP-${VERSION}"
    echo "== $TAG"
    ASSETS=$(gh release view "$TAG" --json assets -q '.assets[].name' | grep '\.rpm$' || true)
    [ -n "$ASSETS" ] || { echo "no .rpm assets"; continue; }

    TOUCHED=""
    PURGE=""
    TARGETS=""
    for NAME in $ASSETS; do
        case "$NAME" in
            *-rocky9-*) DISTRO=rocky9 ;;
            *-cs9-*) DISTRO=cs9 ;;
            *-cs10-*) DISTRO=cs10 ;;
            *) echo "Unknown distro in $NAME, skipping"; continue ;;
        esac
        case "$NAME" in
            *amd64*|*x86_64*) ARCH=x86_64 ;;
            *arm64*|*aarch64*) ARCH=aarch64 ;;
            *) echo "Unknown arch in $NAME, skipping"; continue ;;
        esac
        DIR="$STAGE/$DISTRO/$ARCH"
        # Already indexed: drop the entry first, --skip-stat would keep stale checksums
        if [ -e "$DIR/$TAG/$NAME" ]; then
            rm "$DIR/$TAG/$NAME"
            PURGE="$PURGE $DISTRO/$ARCH"
        fi
        TARGETS="$TARGETS $DISTRO/$ARCH/$NAME"
        TOUCHED="$TOUCHED $DISTRO/$ARCH"
    done

    for D in $(echo "$PURGE" | tr ' ' '\n' | sort -u); do
        createrepo_c -q --update --skip-stat --no-database --general-compress-type=gz \
            --baseurl "$BASEURL" "$STAGE/$D"
    done

    for T in $TARGETS; do
        mkdir -p "$STAGE/$(dirname "$T")/$TAG"
        gh release download "$TAG" -p "$(basename "$T")" -D "$STAGE/$(dirname "$T")/$TAG" --clobber
    done

    for D in $(echo "$TOUCHED" | tr ' ' '\n' | sort -u); do
        createrepo_c -q --update --skip-stat --no-database --general-compress-type=gz \
            --baseurl "$BASEURL" "$STAGE/$D"
        # Back to placeholders to keep disk usage at one release
        find "$STAGE/$D/$TAG" -name '*.rpm' -exec truncate -s 0 {} +
    done
done

for DISTRO in $DISTROS; do
    for ARCH in $ARCHS; do
        OUT="$REPO_DIR/$DISTRO/$ARCH"
        if [ -f "$STAGE/$DISTRO/$ARCH/repodata/repomd.xml" ]; then
            mkdir -p "$OUT"
            rm -rf "$OUT/repodata"
            cp -r "$STAGE/$DISTRO/$ARCH/repodata" "$OUT/"
        elif [ "$REBUILD" = 1 ]; then
            # Nothing left to index: drop repodata pointing at removed files
            rm -rf "$OUT/repodata"
        fi
        [ -f "$OUT/repodata/repomd.xml" ] || continue
        PRIMARY=$(grep -o 'href="repodata/[^"]*primary\.xml[^"]*"' "$OUT/repodata/repomd.xml" | cut -d'"' -f2)
        echo "$DISTRO/$ARCH: $(decompress "$OUT/$PRIMARY" | grep -c '<package ') packages"
    done
done
