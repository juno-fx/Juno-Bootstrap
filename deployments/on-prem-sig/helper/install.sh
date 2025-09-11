#!/usr/bin/env bash


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck source=helper/lib.sh
source "${SCRIPT_DIR}/../../../helper/lib.sh"

set -euo pipefail

declare -A REGISTRY_MIRRORS_MAP

echo
echo "==============================================="
echo "   🚀 Official Juno Innovations K3s Provisioner for On-Premises"
echo "==============================================="
echo

TAR_FILE="juno-oneclick.tar.gz"

download_latest_oneclick() {
    echo "📦 Fetching the latest installer release..."
    LATEST_TAG=$(curl -s https://api.github.com/repos/juno-fx/K8s-Playbooks/releases/latest \
        | grep '"tag_name":' \
        | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')
    echo "🔖 Latest tag found: $LATEST_TAG"

    echo "📥 Downloading installer tarball to $TAR_FILE ..."
    curl -fsSL -o "$TAR_FILE" "https://github.com/juno-fx/K8s-Playbooks/releases/download/${LATEST_TAG}/juno-oneclick.tar.gz"
    echo "✅ Download complete."
    echo
}


prompt_airgap_values() {
    REGISTRIES_TO_MIRROR="docker.io registry.k8s.io nvcr.io quay.io ghcr.io"
    for REGISTRY in $REGISTRIES_TO_MIRROR; do
        MIRROR_URL=""
        while [ -z "$MIRROR_URL" ]; do
            prompt MIRROR_URL "🌐 Enter the http(s) mirror URL for $REGISTRY: " ""
            if [ -n "$MIRROR_URL" ]; then
                break
            fi
            echo "❌ Error: Mirror URL cannot be empty."
        done
        REGISTRY_MIRRORS_MAP["$REGISTRY"]="$MIRROR_URL"
    done

    REGISTRY_USERNAME=""
    REGISTRY_PASSWORD=""
    REGISTRY_HOST_PORT=""

    prompt REGISTRY_USERNAME "👤 Enter the username for private registry (leave blank if not using authentication): " ""
    if [ -n "$REGISTRY_USERNAME" ]; then
        prompt REGISTRY_PASSWORD "🔑 Enter the password for private registry (leave blank if not using authentication): " ""
        echo "🌐 Enter the host part of the earlier URLs, without the http protocol."
        echo "Example: for https://registry.example.com, you enter registry.example.com"
        echo "For http://registry.example.com:5000, you enter registry.example.com:5000"
        prompt REGISTRY_HOST_PORT "Your value:" ""
    fi

}

append_airgap_values_to_yaml() {
    {
        echo "_oneclick_registries:"
        echo "  mirrors:"
        for REGISTRY in "${!REGISTRY_MIRRORS_MAP[@]}"; do
            MIRROR_URL="${REGISTRY_MIRRORS_MAP[$REGISTRY]}"
            echo "    \"${REGISTRY}\":"
            echo "      endpoint:"
            echo "        - \"${MIRROR_URL}\""
        done
        if [ -n "${REGISTRY_USERNAME}" ]; then
            echo "  configs:"
            echo "    \"${REGISTRY_HOST_PORT}\":"
            echo "      auth:"
            echo "        username: \"${REGISTRY_USERNAME}\""
            echo "        password: \"${REGISTRY_PASSWORD}\""
        fi
    } >> ".values.yaml"
}

ONECLICK_ARCHIVE_PATH="${ONECLICK_ARCHIVE_PATH:-juno-oneclick.tar.gz}"


if [[ "$IS_OFFLINE_INSTALL" =~ ^[Yy]$ ]]; then
    echo "Note: the installer can be downloaded from: https://github.com/juno-fx/K8s-Playbooks/releases"
    prompt ONECLICK_ARCHIVE_PATH "📂 Enter the path to the oneclick archive: " "${ONECLICK_ARCHIVE_PATH:-}"
    if [[ ! -f "$ONECLICK_ARCHIVE_PATH" ]]; then
        echo "❌ Error: File not found at '$ONECLICK_ARCHIVE_PATH'."
        exit 1
    fi
    echo "✅ Offline installation selected with archive: $ONECLICK_ARCHIVE_PATH"
    TAR_FILE="$ONECLICK_ARCHIVE_PATH"
    prompt_airgap_values
    append_airgap_values_to_yaml
else
    echo "✅ Online installation selected."
    download_latest_oneclick
fi



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
tar -xzf "$TAR_FILE" -C ./
sudo ./juno-oneclickfs/juno-oneclick.install ./.values.yaml
echo "✅ Installation complete!"
echo

# --- Clean up temporary files and extracted directory ---
echo "🧹 Cleaning up temporary files..."

if [[ "$IS_OFFLINE_INSTALL" =~ ^[Yy]$ ]]; then
    echo "⚡ Offline install - preserving provided archive: $TAR_FILE"
else
    echo "🗑️ Removing downloaded archive: $TAR_FILE"
    rm -f "$TAR_FILE"
fi



rm -rf juno-oneclickfs
echo "✅ Cleanup complete!"
