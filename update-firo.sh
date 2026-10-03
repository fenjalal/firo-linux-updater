#!/usr/bin/env bash
# Firo binary updater (Linux). Verifies and replaces firod, firo-cli, firo-tx and firo-qt.
# Never touches wallet or datadir files (~/.firo).

set -euo pipefail

REPO="firoorg/firo"
SIGNER_FPR="0186454D63E83D85EF91DE4E1290A1D0FA7EE109"
INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="$SCRIPT_DIR/keys/reuben.asc"

usage() {
    echo "Usage: $0 <version|latest> [--daemon-only]"
    echo "  $0 latest"
    echo "  $0 0.14.18.1 --daemon-only"
    exit 1
}

TARGET=""
DAEMON_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --daemon-only) DAEMON_ONLY=1 ;;
        -h|--help) usage ;;
        *) TARGET="$arg" ;;
    esac
done
[ -n "$TARGET" ] || usage

if [ "$TARGET" = "latest" ]; then
    TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
        | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n 1)"
    [ -n "$TAG" ] || { echo "Could not read latest release from GitHub."; exit 1; }
else
    TAG="$TARGET"
fi
BASE_URL="https://github.com/$REPO/releases/download/v$TAG"

case "$(uname -m)" in
    x86_64)  TARBALL="firo-$TAG-linux64.tar.gz" ;;
    aarch64) TARBALL="firo-$TAG-aarch64-linux-gnu.tar.gz" ;;
    *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

BINARIES=(firod firo-cli firo-tx)
[ "$DAEMON_ONLY" -eq 1 ] || BINARIES+=(firo-qt)

WORKDIR="$(mktemp -d)"
BACKUP_DIR="$WORKDIR/backup"
INSTALL_STARTED=0
INSTALL_OK=0

rollback() {
    echo ""
    echo "New Firo binary failed to start."
    echo "Rolling back to the previous binaries..."
    for bin in "${BINARIES[@]}"; do
        if [ -f "$BACKUP_DIR/$bin" ]; then
            sudo install -m 755 -o root -g root "$BACKUP_DIR/$bin" "$INSTALL_DIR/$bin"
        else
            sudo rm -f "$INSTALL_DIR/$bin"
        fi
    done
    echo "Rollback complete."
}

cleanup() {
    if [ "$INSTALL_STARTED" -eq 1 ] && [ "$INSTALL_OK" -ne 1 ]; then
        rollback
    fi
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "Firo Binary Updater"
echo "────────────────────────────────"
echo "This updater only replaces Firo binaries."
echo "Your wallet and ~/.firo data directory will not be modified."
echo ""
if command -v firod >/dev/null 2>&1; then
    echo "Current version : $(firod --version 2>/dev/null | head -n 1 || echo unknown)"
else
    echo "Current version : not installed"
fi
echo "Target version  : $TAG"
echo "Architecture    : $(uname -m)"
echo "Package         : $TARBALL"
echo "Source          : github.com/$REPO"
echo ""

echo "[1/7] Downloading release..."
curl -fL --progress-bar -o "$WORKDIR/$TARBALL" "$BASE_URL/$TARBALL"
curl -fsSL -o "$WORKDIR/SHA256SUMS" "$BASE_URL/SHA256SUMS"

echo "[2/7] Verifying release signature..."
export GNUPGHOME="$WORKDIR/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --import "$KEY_FILE"
GOT_FPR="$(gpg --batch --with-colons --fingerprint | sed -n 's/^fpr:::::::::\([0-9A-F]*\):$/\1/p' | head -n 1)"
if [ "$GOT_FPR" != "$SIGNER_FPR" ]; then
    echo "Pinned key fingerprint does not match. Refusing to continue."; exit 1
fi
gpg --batch --quiet --verify "$WORKDIR/SHA256SUMS"
echo "      ✓ Signature verified (Firo release key)"

echo "[3/7] Verifying SHA256 checksum..."
(cd "$WORKDIR" && grep " $TARBALL\$" SHA256SUMS | sha256sum -c --quiet -)
echo "      ✓ SHA256 verified"

echo "[4/7] Extracting and checking binaries..."
tar -xzf "$WORKDIR/$TARBALL" -C "$WORKDIR"
BIN_DIR="$(dirname "$(find "$WORKDIR" -type f -name firod -path '*/bin/*' | head -n 1)")"
for bin in "${BINARIES[@]}"; do
    [ -f "$BIN_DIR/$bin" ] || { echo "$bin not found in the archive"; exit 1; }
done
NEW_VERSION="$("$BIN_DIR/firod" --version | head -n 1)"
case "$NEW_VERSION" in
    *"$TAG"*) ;;
    *) echo "Archive version mismatch: $NEW_VERSION"; exit 1 ;;
esac
echo "      ✓ $NEW_VERSION"

echo "[5/7] Stopping firod (if running)..."
WAS_RUNNING=0
if command -v firo-cli >/dev/null 2>&1 && firo-cli getblockcount >/dev/null 2>&1; then
    WAS_RUNNING=1
    echo "firod is currently running."
    echo "The updater needs to stop firod before replacing binaries."
    if [ -t 0 ]; then
        read -r -p "Stop firod and continue? [y/N] " answer
    else
        answer="n"
    fi
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled. firod is still running; nothing was changed."; exit 1 ;;
    esac
    firo-cli stop >/dev/null 2>&1 || true
    for _ in $(seq 1 60); do
        firo-cli getblockcount >/dev/null 2>&1 || break
        sleep 1
    done
    if firo-cli getblockcount >/dev/null 2>&1; then
        echo "firod is still running. Stop it manually and run the updater again."; exit 1
    fi
    echo "      ✓ Stopped"
else
    echo "      ✓ Not running"
fi

echo "[6/7] Backing up and installing binaries..."
mkdir "$BACKUP_DIR"
for bin in "${BINARIES[@]}"; do
    if [ -f "$INSTALL_DIR/$bin" ]; then
        sudo cp -p "$INSTALL_DIR/$bin" "$BACKUP_DIR/$bin"
    fi
done
INSTALL_STARTED=1
for bin in "${BINARIES[@]}"; do
    sudo install -m 755 -o root -g root "$BIN_DIR/$bin" "$INSTALL_DIR/$bin"
    echo "      ✓ $bin -> $INSTALL_DIR/$bin"
done

echo "[7/7] Verifying installed version..."
INSTALLED="$("$INSTALL_DIR/firod" --version | head -n 1)"
case "$INSTALLED" in
    *"$TAG"*) ;;
    *) echo "Installed version mismatch: $INSTALLED"; exit 1 ;;
esac
INSTALL_OK=1
echo "      ✓ $INSTALLED"

echo ""
echo "Firo Core $TAG installed successfully."
echo ""
echo "Wallet/datadir:"
echo "  ~/.firo"
echo ""
echo "Status:"
echo "  ✓ Not modified"
echo ""
if [ "$WAS_RUNNING" -eq 1 ]; then
    echo "firod was stopped for the update. Start it again:"
else
    echo "To start the node:"
fi
echo "  firod              (runs in this terminal)"
echo "  firod -daemon      (runs in the background)"
[ "$DAEMON_ONLY" -eq 1 ] || echo "  firo-qt            (opens the wallet)"
