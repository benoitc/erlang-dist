#!/bin/bash
# Add the .deb assets of OTP releases to the flat APT repositories.
# Each distro has its index (Packages, Packages.gz, Release) on a release
# tagged apt-<distro>; package entries point at the OTP-<version> assets.
#
#   deb [trusted=yes] https://github.com/OWNER/REPO/releases/download/ apt-ubuntu2404/
#
# Usage: ./apt-index.sh [--rebuild] VERSION...
#   --rebuild  start from empty indexes and index only VERSION...
#
# Requires: gh (authenticated), dpkg-dev, apt-utils

set -euo pipefail

REBUILD=0
if [ "${1:-}" = "--rebuild" ]; then
    REBUILD=1
    shift
fi
[ $# -gt 0 ] || { echo "No version given"; exit 1; }

GH_REPO="${GH_REPO:-${GITHUB_REPOSITORY:?GH_REPO or GITHUB_REPOSITORY required}}"
export GH_REPO
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

DISTROS="ubuntu2204 ubuntu2404 ubuntu2604 debian11 debian12 debian13"

for DISTRO in $DISTROS; do
    mkdir -p "$WORK/$DISTRO"
    : > "$WORK/$DISTRO/Packages"
    if [ "$REBUILD" = 0 ]; then
        gh release download "apt-$DISTRO" -p Packages -D "$WORK/$DISTRO" --clobber 2>/dev/null || true
    fi
done

for VERSION in "$@"; do
    TAG="OTP-${VERSION}"
    echo "== $TAG"
    ASSETS=$(gh release view "$TAG" --json assets -q '.assets[].name' | grep '\.deb$' || true)
    [ -n "$ASSETS" ] || { echo "no .deb assets"; continue; }

    for NAME in $ASSETS; do
        DISTRO=""
        for D in $DISTROS; do
            case "$NAME" in *-"$D"-*) DISTRO=$D ;; esac
        done
        [ -n "$DISTRO" ] || { echo "Unknown distro in $NAME, skipping"; continue; }

        gh release download "$TAG" -p "$NAME" -D "$WORK" --clobber
        DEB="$WORK/$NAME"
        FILENAME="$TAG/$NAME"
        PACKAGES="$WORK/$DISTRO/Packages"

        # Drop a previous entry for the same file, then append the new one
        awk -v f="Filename: $FILENAME" 'BEGIN { RS = ""; ORS = "\n\n" }
            { n = split($0, l, "\n"); keep = 1
              for (i = 1; i <= n; i++) if (l[i] == f) keep = 0
              if (keep) print }' "$PACKAGES" > "$PACKAGES.new"
        {
            dpkg-deb -f "$DEB"
            echo "Filename: $FILENAME"
            echo "Size: $(stat -c%s "$DEB")"
            echo "MD5sum: $(md5sum "$DEB" | cut -d' ' -f1)"
            echo "SHA256: $(sha256sum "$DEB" | cut -d' ' -f1)"
            echo
        } >> "$PACKAGES.new"
        mv "$PACKAGES.new" "$PACKAGES"
        rm -f "$DEB"
    done
done

for DISTRO in $DISTROS; do
    DIR="$WORK/$DISTRO"
    [ -s "$DIR/Packages" ] || continue
    gzip -9kf "$DIR/Packages"
    apt-ftparchive \
        -o APT::FTPArchive::Release::Origin=erlang-dist \
        -o APT::FTPArchive::Release::Label="Erlang Distribution" \
        -o APT::FTPArchive::Release::Suite="apt-$DISTRO" \
        -o APT::FTPArchive::Release::Description="Pre-built Erlang/OTP packages for $DISTRO" \
        release "$DIR" > "$WORK/Release"
    mv "$WORK/Release" "$DIR/Release"

    if ! gh release view "apt-$DISTRO" >/dev/null 2>&1; then
        gh release create "apt-$DISTRO" --prerelease --latest=false \
            --title "APT repository: $DISTRO" \
            --notes "APT index for $DISTRO. Packages are the assets of the OTP-* releases.

\`\`\`
echo \"deb [trusted=yes] https://github.com/${GH_REPO}/releases/download/ apt-$DISTRO/\" | sudo tee /etc/apt/sources.list.d/erlang-dist.list
\`\`\`"
    fi
    gh release upload "apt-$DISTRO" "$DIR/Packages" "$DIR/Packages.gz" "$DIR/Release" --clobber
    echo "$DISTRO: $(grep -c '^Package:' "$DIR/Packages") packages"
done
