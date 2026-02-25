#!/bin/sh
# Universal Erlang/OTP installer
# Usage: curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh -s -- [VERSION] [PREFIX]

set -e

# Configuration
REPO_OWNER="${ERLANG_DIST_OWNER:-USER}"
REPO_NAME="${ERLANG_DIST_REPO:-erlang-dist}"
DEFAULT_VERSION=""
DEFAULT_PREFIX="/usr/local"

# Colors (only if terminal supports it)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

info() {
    printf "${BLUE}==>${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}==>${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}Warning:${NC} %s\n" "$1"
}

error() {
    printf "${RED}Error:${NC} %s\n" "$1" >&2
    exit 1
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "darwin" ;;
        *)       error "Unsupported operating system: $(uname -s)" ;;
    esac
}

# Detect architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)             error "Unsupported architecture: $(uname -m)" ;;
    esac
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# Get latest version from GitHub API
get_latest_version() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" 2>/dev/null | \
            grep '"tag_name"' | sed -E 's/.*"OTP-([^"]+)".*/\1/' || echo ""
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" 2>/dev/null | \
            grep '"tag_name"' | sed -E 's/.*"OTP-([^"]+)".*/\1/' || echo ""
    fi
}

# Download file
download() {
    url="$1"
    output="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output"
    else
        error "Neither curl nor wget found. Please install one of them."
    fi
}

# Verify checksum
verify_checksum() {
    file="$1"
    expected="$2"

    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        warn "No checksum tool found, skipping verification"
        return 0
    fi

    if [ "$actual" != "$expected" ]; then
        error "Checksum verification failed!\nExpected: $expected\nActual:   $actual"
    fi
}

# Main installation
main() {
    VERSION="${1:-$DEFAULT_VERSION}"
    PREFIX="${2:-$DEFAULT_PREFIX}"

    OS=$(detect_os)
    ARCH=$(detect_arch)

    # macOS uses x86_64 naming
    if [ "$OS" = "darwin" ] && [ "$ARCH" = "amd64" ]; then
        ARCH="x86_64"
    fi

    info "Detected: $OS/$ARCH"

    # Get version if not specified
    if [ -z "$VERSION" ]; then
        info "Fetching latest version..."
        VERSION=$(get_latest_version)
        if [ -z "$VERSION" ]; then
            error "Could not determine latest version. Please specify a version."
        fi
    fi

    info "Installing Erlang/OTP $VERSION to $PREFIX"

    # Construct download URL
    TARBALL="erlang-${VERSION}-${OS}-${ARCH}.tar.gz"
    BASE_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/OTP-${VERSION}"
    TARBALL_URL="${BASE_URL}/${TARBALL}"
    CHECKSUMS_URL="${BASE_URL}/SHA256SUMS"

    # Create temp directory
    TMPDIR=$(mktemp -d)
    trap 'rm -rf "$TMPDIR"' EXIT

    # Download checksum file
    info "Downloading checksums..."
    download "$CHECKSUMS_URL" "$TMPDIR/SHA256SUMS" || error "Failed to download checksums"

    # Extract expected checksum
    EXPECTED_CHECKSUM=$(grep "$TARBALL" "$TMPDIR/SHA256SUMS" | awk '{print $1}')
    if [ -z "$EXPECTED_CHECKSUM" ]; then
        error "No checksum found for $TARBALL. This platform/version combination may not be available."
    fi

    # Download tarball
    info "Downloading $TARBALL..."
    download "$TARBALL_URL" "$TMPDIR/$TARBALL" || error "Failed to download tarball"

    # Verify checksum
    info "Verifying checksum..."
    verify_checksum "$TMPDIR/$TARBALL" "$EXPECTED_CHECKSUM"
    success "Checksum verified"

    # Check if we need sudo
    if [ ! -w "$PREFIX" ]; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO="sudo"
            info "Installing to $PREFIX (requires sudo)..."
        else
            error "Cannot write to $PREFIX and sudo is not available"
        fi
    else
        SUDO=""
        info "Installing to $PREFIX..."
    fi

    # Create prefix if it doesn't exist
    $SUDO mkdir -p "$PREFIX"

    # Extract tarball
    $SUDO tar xzf "$TMPDIR/$TARBALL" -C "$PREFIX" --strip-components=2

    success "Erlang/OTP $VERSION installed successfully!"

    # Check if erl is in PATH
    if ! command -v erl >/dev/null 2>&1; then
        echo ""
        warn "erl is not in your PATH"
        echo ""
        echo "Add the following to your shell profile:"
        echo ""
        echo "  export PATH=\"$PREFIX/bin:\$PATH\""
        echo ""
    fi

    # Show version
    if command -v "$PREFIX/bin/erl" >/dev/null 2>&1; then
        echo ""
        info "Installed version:"
        "$PREFIX/bin/erl" -eval 'io:format("Erlang/OTP ~s~n", [erlang:system_info(otp_release)]), halt().' -noshell
    fi
}

# Run main function
main "$@"
