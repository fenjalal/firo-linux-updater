# Firo Linux Updater

Updates `firod`, `firo-cli`, `firo-qt` and `firo-tx` to an official Firo release.
It does not touch your wallet or `~/.firo` data.

## Requirements

- Linux x86_64 or aarch64 with glibc 2.30 or newer
- `curl`, `tar`, `sha256sum`, `sudo`

## Quick start

```bash
git clone https://github.com/fenjalal/firo-updater.git
cd firo-updater
chmod +x update-firo.sh
./update-firo.sh 0.14.18.1
```

Replace `0.14.18.1` with the version you want.

## What it does

1. Downloads the release tarball from github.com/firoorg/firo.
2. Verifies it against the official `SHA256SUMS`.
3. Extracts it to a temporary folder.
4. Stops `firod` if it is running.
5. Copies the four binaries to `/usr/local/bin`.

## Start after the update

```bash
firod              # runs in this terminal
firod -daemon      # runs in the background
firo-qt            # opens the wallet
```

## Notes

- Tested on Kali Linux only.
- Needs `sudo` to write to `/usr/local/bin`.
