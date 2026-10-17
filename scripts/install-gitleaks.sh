#!/usr/bin/env sh
# Install gitleaks into .bin/ (repo-local, gitignored): pinned to one version and
# verified against a published SHA-256 BEFORE anything is extracted.
#
#   sh scripts/install-gitleaks.sh
#
# Derived from reference/node-pnpm/scripts/install-gitleaks.sh, which is an exhibit.
# Three differences are deliberate:
#   * POSIX sh, not bash.
#   * A failed download, an unsupported platform and an unverifiable tarball are all
#     HARD failures. The exhibit soft-skips with exit 0 — an availability tradeoff for
#     a developer's laptop, where scanning merely degrades. Here the install is what
#     lets CI run the scan cases at all: one that silently did not install reads as
#     installed, and every case that needs the scanner is then skipped.
#   * No project-specific opt-out variable.
#
# THE FOUR HASHES BELOW WERE COPIED from the exhibit, which took them from the
# release's published checksums file. They were not re-fetched here. CI has since
# exercised two of the four with real downloads — linux/x64 and darwin/arm64, on
# 2026-10-17 — and the other two (darwin/x64, linux/arm64) have never been downloaded.
# Bumping GITLEAKS_VERSION means refreshing all four.
#
# TEST SEAM: GITLEAKS_DOWNLOAD_BASE redirects WHERE the tarball comes from, never what
# it must hash to, so it cannot be used to install anything the pinned hashes do not
# vouch for. scripts/check-ci.test.sh uses a file:// base to exercise the failure
# paths without a network.
#
# Messages never print an absolute path.

set -e

GITLEAKS_VERSION="8.30.1"
here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(dirname "$here")"
bin_dir="$repo_root/.bin"
target="$bin_dir/gitleaks"

# Already at the pinned version: nothing to do, and nothing is downloaded.
if [ -x "$target" ]; then
  current="$("$target" version 2>/dev/null || true)"
  case "$current" in
    "$GITLEAKS_VERSION"|"v$GITLEAKS_VERSION") exit 0 ;;
  esac
fi

case "$(uname -s)" in
  Darwin) os="darwin" ;;
  Linux)  os="linux" ;;
  *) echo "❌ install-gitleaks: unsupported OS. Install gitleaks $GITLEAKS_VERSION by hand:" >&2
     echo "   https://github.com/gitleaks/gitleaks/releases/tag/v$GITLEAKS_VERSION" >&2
     exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64)  arch="x64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) echo "❌ install-gitleaks: unsupported architecture. Install gitleaks $GITLEAKS_VERSION by hand:" >&2
     echo "   https://github.com/gitleaks/gitleaks/releases/tag/v$GITLEAKS_VERSION" >&2
     exit 1 ;;
esac

asset="gitleaks_${GITLEAKS_VERSION}_${os}_${arch}.tar.gz"
base="${GITLEAKS_DOWNLOAD_BASE:-https://github.com/gitleaks/gitleaks/releases/download/v$GITLEAKS_VERSION}"

# Every os/arch that reaches this point is one of these four.
case "${os}_${arch}" in
  darwin_arm64) expected_sha256="b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5" ;;
  darwin_x64) expected_sha256="dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709" ;;
  linux_arm64) expected_sha256="e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080" ;;
  linux_x64) expected_sha256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb" ;;
esac

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

echo "📦 install-gitleaks: downloading $asset"
if ! curl -fsSL "$base/$asset" -o "$tmpdir/gitleaks.tar.gz"; then
  echo "❌ install-gitleaks: the download failed, so the scanner is NOT installed." >&2
  echo "   A scanner that did not install must not read as installed." >&2
  exit 1
fi

# Verify before extracting. A MISMATCH is never softened: do not extract or install a
# tarball that is not byte-for-byte the audited release asset.
if command -v sha256sum >/dev/null 2>&1; then
  actual_sha256="$(sha256sum "$tmpdir/gitleaks.tar.gz" | awk '{ print $1 }')"
else
  actual_sha256="$(shasum -a 256 "$tmpdir/gitleaks.tar.gz" | awk '{ print $1 }')"
fi
if [ "$actual_sha256" != "$expected_sha256" ]; then
  echo "❌ install-gitleaks: SHA-256 mismatch for $asset" >&2
  echo "   expected: $expected_sha256" >&2
  echo "   actual:   $actual_sha256" >&2
  echo "   Refusing to install. Compare against the release's published checksums file:" >&2
  echo "   https://github.com/gitleaks/gitleaks/releases/tag/v$GITLEAKS_VERSION" >&2
  exit 1
fi

tar -xzf "$tmpdir/gitleaks.tar.gz" -C "$tmpdir" gitleaks
mkdir -p "$bin_dir"
mv "$tmpdir/gitleaks" "$target"
chmod +x "$target"

# Trust, but confirm what was installed is what the pin says.
installed="$("$target" version 2>/dev/null || true)"
case "$installed" in
  "$GITLEAKS_VERSION"|"v$GITLEAKS_VERSION") ;;
  *) echo "❌ install-gitleaks: installed a binary that does not report version $GITLEAKS_VERSION." >&2
     rm -f "$target"
     exit 1 ;;
esac
echo "✅ install-gitleaks: installed gitleaks $GITLEAKS_VERSION at .bin/gitleaks"
