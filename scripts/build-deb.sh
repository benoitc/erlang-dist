#!/bin/bash
# Build .deb package for Erlang/OTP
# Usage: ./build-deb.sh VERSION ARCH [DISTRO]

set -e

VERSION="${1:?Version required}"
ARCH="${2:?Architecture required}"
DISTRO="${3:-ubuntu}"

# Package naming
PKG_NAME="erlang-${VERSION%%.*}"  # e.g., erlang-27
PKG_VERSION="${VERSION}"
PKG_ARCH="$ARCH"
PKG_DIR="${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}"

echo "Building .deb package: $PKG_DIR"

# Create package directory structure
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/local"

# Copy installed files
if [ -d "install/usr/local" ]; then
    cp -a install/usr/local/* "$PKG_DIR/usr/local/"
else
    echo "Error: install/usr/local not found"
    exit 1
fi

# Calculate installed size (in KB)
INSTALLED_SIZE=$(du -sk "$PKG_DIR/usr/local" | cut -f1)

# Create control file
cat > "$PKG_DIR/DEBIAN/control" << EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Section: interpreters
Priority: optional
Architecture: $PKG_ARCH
Installed-Size: $INSTALLED_SIZE
Depends: libc6, libncurses6 | libncurses5, libssl3 | libssl1.1, zlib1g
Recommends: libwxgtk3.2-1 | libwxgtk3.0-gtk3-0v5
Suggests: erlang-doc
Maintainer: Erlang Dist <erlang-dist@example.com>
Homepage: https://www.erlang.org/
Description: Erlang/OTP $VERSION
 Erlang is a programming language and runtime system for building
 massively scalable soft real-time systems with requirements on
 high availability.
 .
 This package provides Erlang/OTP version $VERSION pre-built binaries.
EOF

# Create conffiles (empty, but good practice)
touch "$PKG_DIR/DEBIAN/conffiles"

# Create postinst script
cat > "$PKG_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/sh
set -e

# Update alternatives (if update-alternatives is available)
if command -v update-alternatives >/dev/null 2>&1; then
    # Get the version from the package name
    PKG_VERSION=$(dpkg-query -W -f='${Version}' "$(dpkg -S "$0" 2>/dev/null | cut -d: -f1)" 2>/dev/null || echo "0")
    PRIORITY=$(echo "$PKG_VERSION" | sed 's/[^0-9]//g' | cut -c1-4)
    PRIORITY=${PRIORITY:-100}

    update-alternatives --install /usr/bin/erl erl /usr/local/bin/erl "$PRIORITY" \
        --slave /usr/bin/erlc erlc /usr/local/bin/erlc \
        --slave /usr/bin/escript escript /usr/local/bin/escript \
        --slave /usr/bin/dialyzer dialyzer /usr/local/bin/dialyzer \
        --slave /usr/bin/typer typer /usr/local/bin/typer 2>/dev/null || true
fi

exit 0
EOF
chmod 755 "$PKG_DIR/DEBIAN/postinst"

# Create prerm script
cat > "$PKG_DIR/DEBIAN/prerm" << 'EOF'
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ]; then
    if command -v update-alternatives >/dev/null 2>&1; then
        update-alternatives --remove erl /usr/local/bin/erl 2>/dev/null || true
    fi
fi

exit 0
EOF
chmod 755 "$PKG_DIR/DEBIAN/prerm"

# Set permissions
find "$PKG_DIR" -type d -exec chmod 755 {} \;
find "$PKG_DIR/usr/local/bin" -type f -exec chmod 755 {} \; 2>/dev/null || true
find "$PKG_DIR/usr/local/lib" -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null || true

# Build the package
dpkg-deb --build --root-owner-group "$PKG_DIR"

# Rename to standard format
mv "${PKG_DIR}.deb" "${PKG_NAME}_${PKG_VERSION}-1_${PKG_ARCH}.deb"

echo "Created: ${PKG_NAME}_${PKG_VERSION}-1_${PKG_ARCH}.deb"

# Generate package info
dpkg-deb -I "${PKG_NAME}_${PKG_VERSION}-1_${PKG_ARCH}.deb"
