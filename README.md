# Erlang/OTP Distribution

Pre-built Erlang/OTP binaries for multiple platforms, distributed via GitHub Releases.

## Quick Install

```bash
# Install latest version
curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh

# Install specific version
curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh -s -- 27.2

# Install to custom prefix
curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh -s -- 27.2 /opt/erlang
```

## Installation Methods

### Universal Installer (All Platforms)

The universal installer detects your OS and architecture, downloads the appropriate tarball, verifies the checksum, and extracts to `/usr/local` (or a custom prefix).

```bash
curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh -s -- [VERSION] [PREFIX]
```

### APT Repository (Debian/Ubuntu)

```bash
# Add repository (unsigned for now)
echo "deb [trusted=yes] https://benoitc.github.io/erlang-dist/apt stable main" | \
    sudo tee /etc/apt/sources.list.d/erlang-dist.list

# Install
sudo apt update
sudo apt install erlang-27
```

### YUM/DNF Repository (RHEL/Rocky/CentOS)

```bash
# Rocky Linux 9
sudo curl -fsSL https://benoitc.github.io/erlang-dist/rpm/erlang-dist-rocky9.repo -o /etc/yum.repos.d/erlang-dist.repo

# CentOS Stream 9
sudo curl -fsSL https://benoitc.github.io/erlang-dist/rpm/erlang-dist-cs9.repo -o /etc/yum.repos.d/erlang-dist.repo

# CentOS Stream 10
sudo curl -fsSL https://benoitc.github.io/erlang-dist/rpm/erlang-dist-cs10.repo -o /etc/yum.repos.d/erlang-dist.repo

# Install
sudo dnf install erlang-27
```

### Manual Download

Download tarballs directly from [GitHub Releases](https://github.com/benoitc/erlang-dist/releases).

```bash
# Download
curl -fsSL https://github.com/benoitc/erlang-dist/releases/download/OTP-27.2/erlang-27.2-linux-amd64.tar.gz -o erlang.tar.gz

# Verify checksum
curl -fsSL https://github.com/benoitc/erlang-dist/releases/download/OTP-27.2/SHA256SUMS | grep linux-amd64 | sha256sum -c

# Extract
sudo tar xzf erlang.tar.gz -C /
```

## Supported Platforms

| Platform | Version | Architecture | Package Types |
|----------|---------|--------------|---------------|
| Ubuntu | 22.04, 24.04 | amd64, arm64 | .deb, tarball |
| Debian | 11, 12 | amd64 | .deb, tarball |
| Rocky Linux | 9 | amd64, arm64 | .rpm, tarball |
| CentOS Stream | 9, 10 | amd64, arm64 | .rpm, tarball |
| macOS | 14+ | arm64 (Apple Silicon) | tarball |

## Available Versions

**OTP 28 (current):**
- 28.3.2 (latest)
- 28.2, 28.1.1, 28.0.4

**OTP 27 (LTS):**
- 27.3.4.8 (latest)
- 27.2.4, 27.1.3, 27.0.1

Builds are automatically triggered when new releases are published on [erlang/otp](https://github.com/erlang/otp). The latest patch version for each minor series is built and maintained.

## Build Configuration

All builds include:
- Thread support
- SMP support
- Kernel poll
- SSL/TLS support (dynamically linked)
- JIT compilation (where supported)
- WxWidgets (when available)

## Verification

All releases include SHA256 checksums. Verify downloads with:

```bash
# Linux
sha256sum -c SHA256SUMS 2>/dev/null | grep erlang-27.2-linux-amd64.tar.gz

# macOS
shasum -a 256 -c SHA256SUMS 2>/dev/null | grep erlang-27.2-darwin-arm64.tar.gz
```

## Contributing

To request a new platform or report issues, please open an issue on GitHub.

## License

The distribution scripts in this repository are MIT licensed. Erlang/OTP itself is Apache 2.0 licensed.
