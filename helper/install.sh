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

# --- Deployment Target Selection ---
echo "==============================================="
echo "   🌐 Choose Deployment Target"
echo "==============================================="
echo "1) Existing Cluster"
echo "2) On Prem K3s"
echo "3) CoreWeave"
echo

# Allow environment override
if [[ -n "${DEPLOY_TARGET:-}" ]]; then
    CHOICE="$DEPLOY_TARGET"
    echo "⚡ DEPLOY_TARGET set to: $CHOICE"
else
    read -rp "Enter choice [1-3]: " CHOICE
fi

case "$CHOICE" in
    1|"Existing Cluster"|"existing")
        TARGET_SCRIPT="existing-sig/helper/install.sh"
        ;;
    2|"On Prem K3s"|"onprem"|"ansible")
        TARGET_SCRIPT="on-prem-sig/helper/install.sh"
        ;;
    3|"CoreWeave"|"coreweave")
        TARGET_SCRIPT="coreweave-sig/helper/install.sh"
        ;;
    *)
        echo "❌ Invalid selection."
        exit 1
        ;;
esac

echo
echo "✅ You selected: $TARGET_SCRIPT"
echo "➡️  Next step: running deployment script from repo..."

# Run the chosen script from GitHub
curl -fsSL "https://raw.githubusercontent.com/juno-fx/Juno-Bootstrap/$BRANCH/deployments/${TARGET_SCRIPT}" | bash -

# --- Clean up temporary files ---
echo
echo "🧹 Cleaning up temporary files..."
rm -f "$TEMPLATE_FILE"
echo "✅ Cleanup complete!"
