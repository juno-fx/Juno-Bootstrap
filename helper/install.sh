#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# shellcheck source=helper/lib.sh
source "${SCRIPT_DIR}/lib.sh"

echo
echo "==============================================="
echo "   🚀 Official Juno Innovations One Click Orion Installer"
echo "==============================================="
echo



TEMPLATE_FILE="$(mktemp)"
cp "$SCRIPT_DIR/values.yaml" "$TEMPLATE_FILE"

# Genesis, ingress-nginx, and GPU Operator repoURL/version (defaults from values.yaml/comments) — only prompt if airgapped
# ToDo: add support for both OCI and chart repos!!!
# ToDo: add auth support for git repos
GENESIS_REPO_URL="${GENESIS_REPO_URL:-https://github.com/juno-fx/Genesis-Deployment.git}"
GENESIS_VERSION="${GENESIS_VERSION:-v2.0.3}"
INGRESS_REPO_URL="${INGRESS_REPO_URL:-https://kubernetes.github.io/ingress-nginx}"
INGRESS_VERSION="${INGRESS_VERSION:-4.12.1}"
GPU_REPO_URL="${GPU_REPO_URL:-https://helm.ngc.nvidia.com/nvidia}"
GPU_VERSION="${GPU_VERSION:-v25.10.1}"

# Hostname (always ask, show system default as suggested value)
SYSTEM_HOST="$(hostname -f)"
SYSTEM_HOST="${SYSTEM_HOST:-orion.example.local}"
prompt INPUT_HOST "🌐 Enter the server's public DNS hostname [$SYSTEM_HOST]: " "$SYSTEM_HOST"
HOSTNAME="$INPUT_HOST"

# Validate that it's not an IP address
if [[ "$HOSTNAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Error: IP addresses are not allowed. Must be a DNS hostname."
    exit 1
fi

# Owner email (env override: OWNER_EMAIL)
prompt OWNER_EMAIL "📧 Enter the owner email: " "${OWNER_EMAIL:-}"

# Owner password (env override: OWNER_PASSWORD)
prompt OWNER_PASSWORD "🔑 Enter the temporary password for the owner: " "${OWNER_PASSWORD:-}"

# Username (env override: USERNAME)
while true; do
    prompt USERNAME "👤 Enter the username (letters only): " "${USERNAME:-}"
    if [[ "$USERNAME" =~ ^[A-Za-z]+$ ]]; then
        break
    else
        echo "❌ Invalid username. Must contain only letters (A–Z, a–z)."
    fi
done

# UID (env override: USER_UID)
prompt USER_UID "🆔 Enter the UID for that user: " "${USER_UID:-}"

echo
echo "==============================================="
echo "   ✅ Collected Installation Information"
echo "-----------------------------------------------"
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
    prompt CONFIRM "❓ Is this information correct? [y/N]: " "N"
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



prompt IS_OFFLINE_INSTALL "📦 Is this an offline installation? [y/N]: " "${IS_OFFLINE_INSTALL:-N}"

if [[ "$IS_OFFLINE_INSTALL" =~ ^[Yy]$ ]]; then
    prompt GENESIS_REPO_URL "🔗 Enter Genesis chart URL [${GENESIS_REPO_URL}]: " "$GENESIS_REPO_URL"
    prompt GENESIS_IS_GIT "❓ Is this a git repo? [y/N]: " "N"
    if [[ "$GENESIS_IS_GIT" =~ ^[Yy]$ ]]; then
        prompt GENESIS_CHART_PATH "📁 Enter the chart path within the repo: " "./"
    fi
    prompt GENESIS_VERSION "🏷️  Enter Genesis chart version [${GENESIS_VERSION}]: " "$GENESIS_VERSION"

    prompt INGRESS_REPO_URL "🌐 Enter ingress-nginx chart URL [${INGRESS_REPO_URL}]: " "$INGRESS_REPO_URL"
    prompt INGRESS_IS_GIT "❓ Is this a git repo? [y/N]: " "N"
    if [[ "$INGRESS_IS_GIT" =~ ^[Yy]$ ]]; then
        prompt INGRESS_CHART_PATH "📁 Enter the chart path within the repo: " ""
    fi
    prompt INGRESS_VERSION "🏷️  Enter ingress-nginx chart version [${INGRESS_VERSION}]: " "$INGRESS_VERSION"

    prompt GPU_REPO_URL "🖥️  Enter GPU Operator chart URL [${GPU_REPO_URL}]: " "$GPU_REPO_URL"
    prompt GPU_IS_GIT "❓ Is this a git repo? [y/N]: " "N"
    if [[ "$GPU_IS_GIT" =~ ^[Yy]$ ]]; then
        prompt GPU_CHART_PATH "📁 Enter the chart path within the repo: " ""
    fi
    prompt GPU_VERSION "🏷️  Enter GPU Operator chart version [${GPU_VERSION}]: " "$GPU_VERSION"
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
    -e "s|REPLACE-GENESIS-URL|$GENESIS_REPO_URL|g" \
    -e "s|REPLACE-GENESIS-VERSION|$GENESIS_VERSION|g" \
    -e "s|REPLACE-INGRESS-URL|$INGRESS_REPO_URL|g" \
    -e "s|REPLACE-INGRESS-VERSION|$INGRESS_VERSION|g" \
    -e "s|REPLACE-GPU-URL|$GPU_REPO_URL|g" \
    -e "s|REPLACE-GPU-VERSION|$GPU_VERSION|g" \
    "$TEMPLATE_FILE" > "$VALUES_FILE"



echo "✅ $VALUES_FILE has been created with your configuration."
echo

if [[ -n "${INGRESS_CHART_PATH:-}" ]]; then
    sed -i "/^ingress:/a\  chartPath: ${INGRESS_CHART_PATH}" "$VALUES_FILE"
fi
if [[ -n "${GPU_CHART_PATH:-}" ]]; then
    sed -i "/^gpu:/a\  chartPath: ${GPU_CHART_PATH}" "$VALUES_FILE"
fi

# --- Deployment Target Selection ---
echo "==============================================="
echo "   🌐 Choose Deployment Target"
echo "==============================================="
echo "1) Existing Cluster"
echo "2) On Prem K3s"
echo
TARGET_SCRIPT=""

while [[ -z "$TARGET_SCRIPT" ]]; do
    if [[ -n "${DEPLOY_TARGET:-}" ]]; then
        CHOICE="$DEPLOY_TARGET"
        echo "⚡ DEPLOY_TARGET set to: $CHOICE"
    else
        prompt CHOICE "Enter choice [1-2]: "
    fi

    case "$CHOICE" in
        1|"Existing Cluster"|"existing")
            TARGET_SCRIPT="existing-sig/helper/install.sh"
            ;;
        2|"On Prem K3s"|"onprem")
            TARGET_SCRIPT="on-prem-sig/helper/install.sh"
            ;;
        *)
            echo "❌ Invalid selection."
            if [[ -n "${DEPLOY_TARGET:-}" ]]; then
                echo "❌ DEPLOY_TARGET value '$DEPLOY_TARGET' is invalid. Please unset it and try again."
                exit 1
            fi
            ;;
    esac
done

echo
echo "✅ You selected: $TARGET_SCRIPT"
echo "➡️  Next step: running deployment script from repo..."

export IS_OFFLINE_INSTALL

"${SCRIPT_DIR}/../deployments/$TARGET_SCRIPT"

echo
echo "🧹 Cleaning up generated values..."
sudo rm -f "$TEMPLATE_FILE"
echo "✅ Cleanup complete!"
