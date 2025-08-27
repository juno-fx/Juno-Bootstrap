#!/usr/bin/env bash

set -euo pipefail

echo
echo "==============================================="
echo "   🚀 Official Juno Innovations One Click Orion Installer"
echo "==============================================="
echo

# Branch handling (default to main)
BRANCH="${BRANCH:-main}"
echo "📌 Using branch: $BRANCH"

# Always (re)download values.yaml template
TEMPLATE_FILE="$(mktemp)"
echo "📥 Downloading values.yaml template from branch: $BRANCH ..."
curl -fsSL -o "$TEMPLATE_FILE" "https://raw.githubusercontent.com/juno-fx/Juno-Bootstrap/refs/heads/$BRANCH/helper/values.yaml"
echo "✅ Template downloaded"
echo

# Hostname (always ask, show system default as suggested value)
SYSTEM_HOST="${HOSTNAME:-orion.example.com}"  # fallback if HOSTNAME is empty
read -rp "🌐 Enter the server's public DNS hostname [${SYSTEM_HOST}]: " INPUT_HOST
HOSTNAME="${INPUT_HOST:-$SYSTEM_HOST}"

# Validate that it's not an IP address
if [[ "$HOSTNAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Error: IP addresses are not allowed. Must be a DNS hostname."
    exit 1
fi

# Owner email (env override: OWNER_EMAIL)
if [[ -z "${OWNER_EMAIL:-}" ]]; then
    read -rp "📧 Enter the owner email: " OWNER_EMAIL
fi

# Owner password (env override: OWNER_PASSWORD)
if [[ -z "${OWNER_PASSWORD:-}" ]]; then
    read -rsp "🔑 Enter the default temporary password for the owner: " OWNER_PASSWORD
    echo
fi

# Username (env override: USERNAME)
if [[ -z "${USERNAME:-}" ]]; then
    while true; do
        read -rp "👤 Enter the username (letters only): " USERNAME
        if [[ "$USERNAME" =~ ^[A-Za-z]+$ ]]; then
            break
        else
            echo "❌ Invalid username. Must contain only letters (A–Z, a–z)."
        fi
    done
else
    if ! [[ "$USERNAME" =~ ^[A-Za-z]+$ ]]; then
        echo "❌ Invalid USERNAME from environment. Must contain only letters (A–Z, a–z)."
        exit 1
    fi
fi

# UID (env override: USER_UID)
if [[ -z "${USER_UID:-}" ]]; then
    read -rp "🆔 Enter the UID for that user: " USER_UID
fi

echo
echo "==============================================="
echo "   ✅ Collected Installation Information"
echo "-----------------------------------------------"
echo "Branch:          $BRANCH"
echo "Hostname:        $HOSTNAME"
echo "Owner Email:     $OWNER_EMAIL"
echo "Owner Password:  [hidden]"
echo "Username:        $USERNAME"
echo "UID:             $USER_UID"
echo "==============================================="
echo

# Confirmation (Y to proceed, default N)
if [[ "${AUTO_CONFIRM:-}" =~ ^[Yy]$ ]]; then
    echo "⚡ AUTO_CONFIRM enabled — skipping prompt."
else
    read -rp "❓ Is this information correct? [y/N]: " CONFIRM
    CONFIRM="${CONFIRM:-N}"  # default to N if empty
    case "$CONFIRM" in
        [Yy])
            echo "👍 Proceeding..."
            ;;
        *)
            echo "❌ Installation aborted by user."
            exit 1
            ;;
    esac
fi

# Always overwrite .values.yaml with updated content
VALUES_FILE=".values.yaml"
echo "📝 Writing final $VALUES_FILE..."
sed \
    -e "s|REPLACE-HOST|$HOSTNAME|g" \
    -e "s|REPLACE-EMAIL|$OWNER_EMAIL|g" \
    -e "s|REPLACE-PASSWORD|$OWNER_PASSWORD|g" \
    -e "s|REPLACE-OWNER|$USERNAME|g" \
    -e "s|REPLACE-UID|$USER_UID|g" \
    "$TEMPLATE_FILE" > "$VALUES_FILE"

echo "✅ $VALUES_FILE has been created with your configuration."
echo

# --- Download the latest installer tarball ---
echo "📦 Fetching the latest installer release..."
LATEST_TAG=$(curl -s https://api.github.com/repos/juno-fx/K8s-Playbooks/releases/latest \
    | grep '"tag_name":' \
    | sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/')
echo "🔖 Latest tag found: $LATEST_TAG"

TAR_FILE="juno-oneclick_${LATEST_TAG}.tar.gz"
echo "📥 Downloading installer tarball to $TAR_FILE ..."
curl -L -o "$TAR_FILE" "https://github.com/juno-fx/K8s-Playbooks/releases/download/${LATEST_TAG}/juno-oneclick.tar.gz"
echo "✅ Download complete."
echo

# --- Ask confirmation before running installer ---
if [[ "${AUTO_CONFIRM:-}" =~ ^[Yy]$ ]]; then
    echo "⚡ AUTO_CONFIRM enabled — proceeding to run installer."
else
    read -rp "❓ Ready to run the installer with sudo? [y/N]: " RUN_INSTALL
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
rm -rf "$TEMPLATE_FILE" "$TAR_FILE" juno-oneclickfs
echo "✅ Cleanup complete!"
