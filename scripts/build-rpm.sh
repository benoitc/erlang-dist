#!/bin/bash
# Build .rpm package for Erlang/OTP
# Usage: ./build-rpm.sh VERSION ARCH [DISTRO]

set -e

VERSION="${1:?Version required}"
ARCH="${2:?Architecture required}"
DISTRO="${3:-el9}"

# Convert architecture name
case "$ARCH" in
    amd64) RPM_ARCH="x86_64" ;;
    arm64) RPM_ARCH="aarch64" ;;
    *)     RPM_ARCH="$ARCH" ;;
esac

# Package naming
PKG_NAME="erlang-${VERSION%%.*}"  # e.g., erlang-27
PKG_VERSION="${VERSION}"
PKG_RELEASE="1.${DISTRO}"

echo "Building .rpm package: ${PKG_NAME}-${PKG_VERSION}-${PKG_RELEASE}.${RPM_ARCH}"

# Setup RPM build environment
RPMBUILD_DIR="$HOME/rpmbuild"
rm -rf "$RPMBUILD_DIR"
mkdir -p "$RPMBUILD_DIR"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# Create tarball from installed files
TARBALL_NAME="${PKG_NAME}-${PKG_VERSION}"
if [ -d "install" ]; then
    mkdir -p "$TARBALL_NAME"
    cp -a install/* "$TARBALL_NAME/"
    tar czf "$RPMBUILD_DIR/SOURCES/${TARBALL_NAME}.tar.gz" "$TARBALL_NAME"
    rm -rf "$TARBALL_NAME"
else
    echo "Error: install directory not found"
    exit 1
fi

# Create spec file
cat > "$RPMBUILD_DIR/SPECS/${PKG_NAME}.spec" << EOF
Name:           $PKG_NAME
Version:        $PKG_VERSION
Release:        $PKG_RELEASE
Summary:        Erlang/OTP $VERSION programming language and runtime

License:        Apache-2.0
URL:            https://www.erlang.org/
Source0:        %{name}-%{version}.tar.gz

BuildArch:      $RPM_ARCH
AutoReqProv:    no

Requires:       glibc
Requires:       ncurses-libs
Requires:       openssl-libs
Requires:       zlib

%description
Erlang is a programming language and runtime system for building
massively scalable soft real-time systems with requirements on
high availability.

This package provides Erlang/OTP version $VERSION pre-built binaries.

%prep
%setup -q

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}
cp -a usr %{buildroot}/

%files
%defattr(-,root,root,-)
/usr/local/bin/*
/usr/local/lib/erlang

%post
# Create symlinks in /usr/bin if they don't exist
for cmd in erl erlc escript dialyzer typer; do
    if [ ! -e /usr/bin/\$cmd ]; then
        ln -sf /usr/local/bin/\$cmd /usr/bin/\$cmd 2>/dev/null || true
    fi
done

%preun
# Remove symlinks on uninstall
if [ "\$1" = "0" ]; then
    for cmd in erl erlc escript dialyzer typer; do
        if [ -L /usr/bin/\$cmd ]; then
            rm -f /usr/bin/\$cmd 2>/dev/null || true
        fi
    done
fi

%changelog
* $(date "+%a %b %d %Y") Erlang Dist <erlang-dist@example.com> - $PKG_VERSION-$PKG_RELEASE
- Built from Erlang/OTP $VERSION source
EOF

# Build the RPM
rpmbuild -bb "$RPMBUILD_DIR/SPECS/${PKG_NAME}.spec"

# Copy to current directory
cp "$RPMBUILD_DIR/RPMS/${RPM_ARCH}/${PKG_NAME}-${PKG_VERSION}-${PKG_RELEASE}.${RPM_ARCH}.rpm" .

echo "Created: ${PKG_NAME}-${PKG_VERSION}-${PKG_RELEASE}.${RPM_ARCH}.rpm"

# Show package info
rpm -qip "${PKG_NAME}-${PKG_VERSION}-${PKG_RELEASE}.${RPM_ARCH}.rpm"
