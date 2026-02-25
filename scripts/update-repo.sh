#!/bin/bash
# Update APT/RPM repository metadata
# Usage: ./update-repo.sh [apt|rpm] PACKAGES_DIR OUTPUT_DIR

set -e

REPO_TYPE="${1:?Repository type required (apt or rpm)}"
PACKAGES_DIR="${2:?Packages directory required}"
OUTPUT_DIR="${3:?Output directory required}"

case "$REPO_TYPE" in
    apt)
        update_apt_repo
        ;;
    rpm)
        update_rpm_repo
        ;;
    *)
        echo "Unknown repository type: $REPO_TYPE"
        echo "Usage: $0 [apt|rpm] PACKAGES_DIR OUTPUT_DIR"
        exit 1
        ;;
esac

update_apt_repo() {
    echo "Updating APT repository..."

    # Create directory structure
    mkdir -p "$OUTPUT_DIR/pool/main"
    mkdir -p "$OUTPUT_DIR/dists/stable/main/binary-amd64"
    mkdir -p "$OUTPUT_DIR/dists/stable/main/binary-arm64"

    # Copy packages
    cp "$PACKAGES_DIR"/*.deb "$OUTPUT_DIR/pool/main/" 2>/dev/null || true

    # Generate Packages files
    cd "$OUTPUT_DIR"

    for ARCH in amd64 arm64; do
        echo "Generating Packages for $ARCH..."
        PACKAGES_FILE="dists/stable/main/binary-${ARCH}/Packages"

        # Use dpkg-scanpackages if available
        if command -v dpkg-scanpackages >/dev/null 2>&1; then
            dpkg-scanpackages --arch "$ARCH" pool/main > "$PACKAGES_FILE"
        else
            # Manual generation
            > "$PACKAGES_FILE"
            for DEB in pool/main/*_${ARCH}.deb; do
                [ -f "$DEB" ] || continue
                dpkg-deb -I "$DEB" control >> "$PACKAGES_FILE"
                echo "Filename: $DEB" >> "$PACKAGES_FILE"
                echo "Size: $(stat -f%z "$DEB" 2>/dev/null || stat -c%s "$DEB")" >> "$PACKAGES_FILE"
                echo "SHA256: $(sha256sum "$DEB" | cut -d' ' -f1)" >> "$PACKAGES_FILE"
                echo "" >> "$PACKAGES_FILE"
            done
        fi

        # Compress
        gzip -9 -c "$PACKAGES_FILE" > "${PACKAGES_FILE}.gz"
    done

    # Generate Release file
    echo "Generating Release file..."
    RELEASE_FILE="dists/stable/Release"

    cat > "$RELEASE_FILE" << EOF
Origin: erlang-dist
Label: Erlang Distribution
Codename: stable
Architectures: amd64 arm64
Components: main
Date: $(date -Ru)
EOF

    # Add checksums
    echo "SHA256:" >> "$RELEASE_FILE"
    for FILE in dists/stable/main/binary-*/Packages*; do
        [ -f "$FILE" ] || continue
        RELPATH=${FILE#dists/stable/}
        SIZE=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE")
        SHA=$(sha256sum "$FILE" | cut -d' ' -f1)
        printf " %s %s %s\n" "$SHA" "$SIZE" "$RELPATH" >> "$RELEASE_FILE"
    done

    # Sign if GPG key is available
    if [ -n "$GPG_KEY_ID" ] && command -v gpg >/dev/null 2>&1; then
        echo "Signing Release file..."
        gpg --default-key "$GPG_KEY_ID" -abs -o "dists/stable/Release.gpg" "dists/stable/Release"
        gpg --default-key "$GPG_KEY_ID" --clearsign -o "dists/stable/InRelease" "dists/stable/Release"
    fi

    echo "APT repository updated at $OUTPUT_DIR"
}

update_rpm_repo() {
    echo "Updating RPM repository..."

    # Create directory structure
    mkdir -p "$OUTPUT_DIR/x86_64"
    mkdir -p "$OUTPUT_DIR/aarch64"

    # Copy packages
    for RPM in "$PACKAGES_DIR"/*amd64*.rpm "$PACKAGES_DIR"/*x86_64*.rpm; do
        [ -f "$RPM" ] && cp "$RPM" "$OUTPUT_DIR/x86_64/"
    done

    for RPM in "$PACKAGES_DIR"/*arm64*.rpm "$PACKAGES_DIR"/*aarch64*.rpm; do
        [ -f "$RPM" ] && cp "$RPM" "$OUTPUT_DIR/aarch64/"
    done

    # Generate repodata
    for ARCH_DIR in "$OUTPUT_DIR/x86_64" "$OUTPUT_DIR/aarch64"; do
        if [ -d "$ARCH_DIR" ] && ls "$ARCH_DIR"/*.rpm >/dev/null 2>&1; then
            echo "Creating repodata for $ARCH_DIR..."
            if command -v createrepo_c >/dev/null 2>&1; then
                createrepo_c --update "$ARCH_DIR"
            elif command -v createrepo >/dev/null 2>&1; then
                createrepo --update "$ARCH_DIR"
            else
                echo "Warning: createrepo not found, skipping repodata generation"
            fi
        fi
    done

    # Sign if GPG key is available
    if [ -n "$GPG_KEY_ID" ] && command -v gpg >/dev/null 2>&1; then
        for ARCH_DIR in "$OUTPUT_DIR/x86_64" "$OUTPUT_DIR/aarch64"; do
            if [ -f "$ARCH_DIR/repodata/repomd.xml" ]; then
                echo "Signing repomd.xml in $ARCH_DIR..."
                gpg --default-key "$GPG_KEY_ID" --detach-sign --armor "$ARCH_DIR/repodata/repomd.xml"
            fi
        done
    fi

    echo "RPM repository updated at $OUTPUT_DIR"
}

# Run the appropriate function
"update_${REPO_TYPE}_repo"
