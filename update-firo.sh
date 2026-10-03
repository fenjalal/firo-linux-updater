#!/usr/bin/env bash
# Firo binary updater (Linux). Replaces only firod, firo-cli, firo-qt, firo-tx.
# Does NOT touch wallet or datadir files (~/.firo).

set -euo pipefail

VERSION="${1:-0.14.18.1}"
INSTALL_DIR="/usr/local/bin"
BASE_URL="https://github.com/firoorg/firo/releases/download/v${VERSION}"

case "$(uname -m)" in
    x86_64)  TARBALL="firo-${VERSION}-linux64.tar.gz" ;;
    aarch64) TARBALL="firo-${VERSION}-aarch64-linux-gnu.tar.gz" ;;
    *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Updating Firo to v${VERSION} (${TARBALL})"

echo "[1/6] Downloading..."
curl -fL --progress-bar -o "$WORKDIR/$TARBALL" "$BASE_URL/$TARBALL"
curl -fsSL -o "$WORKDIR/SHA256SUMS" "$BASE_URL/SHA256SUMS"

echo "[2/6] Verifying checksum..."
(cd "$WORKDIR" && grep " ${TARBALL}\$" SHA256SUMS | sha256sum -c -)

echo "[3/6] Extracting..."
tar -xzf "$WORKDIR/$TARBALL" -C "$WORKDIR"

BIN_DIR="$(dirname "$(find "$WORKDIR" -type f -name firod -path '*/bin/*' | head -n 1)")"
if [ ! -x "$BIN_DIR/firod" ]; then
    echo "firod not found in the archive"; exit 1
fi

NEW_VERSION="$("$BIN_DIR/firod" --version | head -n 1)"
case "$NEW_VERSION" in
    *"$VERSION"*) ;;
    *) echo "Archive version mismatch: $NEW_VERSION"; exit 1 ;;
esac

echo "[4/6] Stopping firod (if running)..."
if command -v firo-cli >/dev/null 2>&1 && firo-cli getblockcount >/dev/null 2>&1; then
    firo-cli stop >/dev/null 2>&1 || true
    for _ in $(seq 1 60); do
        firo-cli getblockcount >/dev/null 2>&1 || break
        sleep 1
    done
fi

echo "[5/6] Installing binaries to ${INSTALL_DIR}..."
for bin in firod firo-cli firo-qt firo-tx; do
    if [ -f "$BIN_DIR/$bin" ]; then
        sudo install -m 755 -o root -g root "$BIN_DIR/$bin" "$INSTALL_DIR/$bin"
        echo "  copied  $bin  ->  $INSTALL_DIR/$bin"
    fi
done

echo "[6/6] Done."
echo ""
echo "Installed: $NEW_VERSION"
echo "Wallet and datadir were not touched."
echo ""
echo "To start the node:"
echo "  firod              (runs in this terminal)"
echo "  firod -daemon      (runs in the background)"
echo "To open the wallet:"
echo "  firo-qt"
