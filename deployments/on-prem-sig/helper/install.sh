#!/usr/bin/env bash

set -euo pipefail

echo
echo "==============================================="
echo "   🚀 Official Juno Innovations K3s Provisioner for On-Premises"
echo "==============================================="
echo

# --- Download the latest installer tarball ---
echo "📦 Fetching the latest installer release..."
LATEST_TAG=$(curl -s https://api.github.com/repos/juno-fx/K8s-Playbooks/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')
echo "🔖 Latest tag found: $LATEST_TAG"

TAR_FILE="juno-oneclick_${LATEST_TAG}.tar.gz"
echo "📥 Downloading installer tarball to $TAR_FILE ..."
curl -fsSL -o "$TAR_FILE" "https://github.com/juno-fx/K8s-Playbooks/releases/download/${LATEST_TAG}/juno-oneclick.tar.gz"
echo "✅ Download complete."
echo

# --- Ask confirmation before running installer ---
if [[ "${AUTO_CONFIRM:-}" =~ ^[Yy]$ ]]; then
    echo "⚡ AUTO_CONFIRM enabled — proceeding to run installer."
else
    read -rp "❓ Ready to run the installer with sudo? [y/N]: " RUN_INSTALL < /dev/tty
    RUN_INSTALL="${RUN_INSTALL:-N}"
    if [[ ! "$RUN_INSTALL" =~ ^[Yy]$ ]]; then
        echo "❌ Installation aborted by user."
        exit 1
    fi
fi

# --- Extract and run the installer ---
echo "🚀 Running the installer..."
tar -xzf "$TAR_FILE"
sudo ./juno-oneclickfs/juno-oneclick.install ./.values.yaml
echo "✅ Installation complete!"
echo

# --- Clean up temporary files and extracted directory ---
echo "🧹 Cleaning up temporary files..."
rm -f "$TAR_FILE"
rm -rf juno-oneclickfs
echo "✅ Cleanup complete!"
