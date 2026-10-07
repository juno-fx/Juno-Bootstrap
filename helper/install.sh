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

# Genesis and ingress-nginx only prompt if airgapped
# ToDo: add support for both OCI and chart repos!!!
# ToDo: add auth support for git repos
GENESIS_REPO_URL="${GENESIS_REPO_URL:-https://github.com/juno-fx/Genesis-Deployment.git}"
GENESIS_VERSION="${GENESIS_VERSION:-v6.0.0}"
INGRESS_REPO_URL="${INGRESS_REPO_URL:-https://kubernetes.github.io/ingress-nginx}"
INGRESS_VERSION="${INGRESS_VERSION:-4.12.1}"

check_command curl "Please install curl:" "y"
check_command git "Please install Git: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git" "y"

if ! check_command helm "⚓ Please install Helm: https://helm.sh/docs/intro/install/" "n"; then
    prompt INSTALL_HELM "⚓ Helm is not installed, install it now?: [y/N]: " "N"
    if [[ $INSTALL_HELM == "y" ]]; then
        install_helm
    fi
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
    "$TEMPLATE_FILE" > "$VALUES_FILE"



echo "✅ $VALUES_FILE has been created with your configuration."
echo

if [[ -n "${GENESIS_CHART_PATH:-}" ]]; then
    set_chart_path "$VALUES_FILE" "genesis" "$GENESIS_CHART_PATH"
fi
if [[ -n "${INGRESS_CHART_PATH:-}" ]]; then
    set_chart_path "$VALUES_FILE" "ingress" "$INGRESS_CHART_PATH"
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
            # Minimum resource limits
            MEMORY_LIMIT_GB=16
            CPU_LIMIT_CORE=4
            echo "❓ Checking available host resources..."
            check_host_resources
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
