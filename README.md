# Firo Binary Updater

Updates `firod`, `firo-cli`, `firo-tx` and `firo-qt` to an official Firo release.
It never touches your wallet or `~/.firo` data.

## Requirements

- Linux x86_64 or aarch64 with glibc 2.30 or newer
- `curl`, `tar`, `gpg`, `sha256sum`, `sudo`

## Usage

```bash
git clone https://github.com/fenjalal/firo-linux-updater.git
cd firo-linux-updater
chmod +x update-firo.sh

./update-firo.sh latest                      # newest official release
./update-firo.sh 0.14.18.1                   # a specific version
./update-firo.sh 0.14.18.1 --daemon-only     # skip firo-qt (servers)
```

## What it checks

1. The release signature (`SHA256SUMS`) against the Firo release key pinned in `keys/reuben.asc`, fingerprint `0186 454D 63E8 3D85 EF91 DE4E 1290 A1D0 FA7E E109`.
2. The SHA256 of the tarball.
3. The version reported by the new `firod`.

If the installed binary fails the version check, the previous binaries are restored automatically.

## Start after the update

```bash
firod              # runs in this terminal
firod -daemon      # runs in the background
firo-qt            # opens the wallet
```

## Notes

- Tested on Kali Linux only.
- Needs `sudo` to write to `/usr/local/bin`.
- The script stops a running `firod` and does not start it again.
