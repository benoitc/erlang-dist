# Erlang/OTP Distribution

Pre-built Erlang/OTP binaries for multiple platforms, distributed via GitHub Releases.

## Quick Install

```bash
# Install latest version
curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh

# Install specific version
curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh -s -- 29.1.1

# Install to custom prefix
curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh -s -- 29.1.1 /opt/erlang
```

## Installation Methods

### Universal Installer (All Platforms)

The universal installer detects your OS and architecture, downloads the appropriate tarball, verifies the checksum, and extracts to `/usr/local` (or a custom prefix).

```bash
curl -fsSL https://benoitc.github.io/erlang-dist/install.sh | sh -s -- [VERSION] [PREFIX]
```

### APT Repository (Debian/Ubuntu)

Each distro has its own index, stored on a release named `apt-<distro>`: `apt-ubuntu2204`, `apt-ubuntu2404`, `apt-ubuntu2604`, `apt-debian11`, `apt-debian12` or `apt-debian13`. The packages are downloaded from the `OTP-<version>` releases.

```bash
# Add repository (unsigned for now), here for Ubuntu 24.04
echo "deb [trusted=yes] https://github.com/benoitc/erlang-dist/releases/download/ apt-ubuntu2404/" | \
    sudo tee /etc/apt/sources.list.d/erlang-dist.list

# Install the latest 29.x, or pin a version
sudo apt update
sudo apt install erlang-29
sudo apt install erlang-29=29.1
```

If you used the previous `https://benoitc.github.io/erlang-dist/apt stable main` line, `apt update` now fails with `changed its 'Label' value ... MOVED`. Replace the line with the one above.

### YUM/DNF Repository (RHEL/Rocky/CentOS)

```bash
# Rocky Linux 9
sudo curl -fsSL https://benoitc.github.io/erlang-dist/rpm/erlang-dist-rocky9.repo -o /etc/yum.repos.d/erlang-dist.repo

# Rocky Linux 10
sudo curl -fsSL https://benoitc.github.io/erlang-dist/rpm/erlang-dist-rocky10.repo -o /etc/yum.repos.d/erlang-dist.repo

# CentOS Stream 9
sudo curl -fsSL https://benoitc.github.io/erlang-dist/rpm/erlang-dist-cs9.repo -o /etc/yum.repos.d/erlang-dist.repo

# CentOS Stream 10
sudo curl -fsSL https://benoitc.github.io/erlang-dist/rpm/erlang-dist-cs10.repo -o /etc/yum.repos.d/erlang-dist.repo

# Any EL9/EL10 distro (uses the CentOS Stream builds)
sudo curl -fsSL https://benoitc.github.io/erlang-dist/rpm/erlang-dist.repo -o /etc/yum.repos.d/erlang-dist.repo

# Install the latest 29.x, or pin a version
sudo dnf install erlang-29
sudo dnf install erlang-29-29.1
```

The repodata is served from GitHub Pages; the packages are downloaded from the `OTP-<version>` releases.

### Windows

Each release includes the official Erlang/OTP x64 build: an installer (`.exe`) and a zip. Both are checked against the digests of the [erlang/otp](https://github.com/erlang/otp/releases) release.

Run the installer, or unpack the zip anywhere; it runs from where you unpack it:

```powershell
$v = "29.1.1"
Invoke-WebRequest "https://github.com/benoitc/erlang-dist/releases/download/OTP-$v/erlang-$v-windows-amd64.zip" -OutFile erlang.zip
Expand-Archive erlang.zip -DestinationPath "$env:LOCALAPPDATA\erlang"
& "$env:LOCALAPPDATA\erlang\bin\erl.exe"
```

Add `%LOCALAPPDATA%\erlang\bin` to your `PATH` to use `erl` from any shell.

### Manual Download

Download tarballs directly from [GitHub Releases](https://github.com/benoitc/erlang-dist/releases).

```bash
# Download
curl -fsSL https://github.com/benoitc/erlang-dist/releases/download/OTP-29.1.1/erlang-29.1.1-linux-amd64.tar.gz -o erlang.tar.gz

# Verify checksum
curl -fsSL https://github.com/benoitc/erlang-dist/releases/download/OTP-29.1.1/SHA256SUMS | grep linux-amd64 | sha256sum -c

# Extract
sudo tar xzf erlang.tar.gz -C /
```

## Supported Platforms

| Platform | Version | Architecture | Package Types |
|----------|---------|--------------|---------------|
| Ubuntu | 22.04, 24.04, 26.04 | amd64, arm64 | .deb, tarball |
| Debian | 12, 13 (11: no new builds) | amd64, arm64 | .deb, tarball |
| Rocky Linux | 9, 10 | amd64, arm64 | .rpm, tarball |
| CentOS Stream | 9, 10 | amd64, arm64 | .rpm, tarball |
| macOS | 14+ | arm64 (Apple Silicon) | tarball |
| Windows | 10, 11, Server | x64 | .exe installer, .zip |

Notes:
- Ubuntu 26.04, Debian 13, Rocky Linux 10 and Debian arm64 packages start with the releases built after 2026-10-04.
- Debian 11 reached end of life and is no longer built. Its packages, up to 29.0.6, stay available from `apt-debian11`.
- Rocky Linux 9 has no packages for the releases between 28.3.2 and 28.5.0.7 (a broken mirror setting in the build, now fixed). 29.1.1, 28.5.0.7 and 27.3.4.11 and later releases are available.

## Available Versions

The latest release of each tracked major version is built:

| Major | Latest |
|-------|--------|
| OTP 29 | 29.1.1 |
| OTP 28 | 28.5.0.7 |
| OTP 27 | 27.3.4.11 |

The full list is on [GitHub Releases](https://github.com/benoitc/erlang-dist/releases); every release stays installable from the APT and YUM repositories. Builds are triggered automatically when [erlang/otp](https://github.com/erlang/otp) publishes a new release of the two most recent major versions.

## Build Configuration

All builds include:
- Thread support
- SMP support
- Kernel poll
- SSL/TLS support: Linux packages use the distro's OpenSSL; the macOS build includes OpenSSL 3.5 (statically linked), so it needs nothing from Homebrew
- JIT compilation (where supported)
- WxWidgets (when available)

## Verification

All releases include SHA256 checksums. Verify downloads with:

```bash
# Linux
sha256sum -c SHA256SUMS 2>/dev/null | grep erlang-29.1.1-linux-amd64.tar.gz

# macOS
shasum -a 256 -c SHA256SUMS 2>/dev/null | grep erlang-29.1.1-darwin-arm64.tar.gz
```

## Contributing

To request a new platform or report issues, please open an issue on GitHub.

## License

The distribution scripts in this repository are MIT licensed. Erlang/OTP itself is Apache 2.0 licensed.
