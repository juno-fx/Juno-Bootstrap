#!/usr/bin/env bash

set -euo pipefail

echo
echo "==============================================="
echo "   🚀 Official Juno Innovations Existing Cluster Installer"
echo "==============================================="
echo

# --- SSH-safe prompt function ---
prompt() {
    local var_name="$1"
    local prompt_text="$2"
    local default_value="${3:-}"

    local input=""
    if [ -t 0 ]; then
        read -rp "$prompt_text" input
    elif [ -r /dev/tty ]; then
        read -rp "$prompt_text" input < /dev/tty
    else
        input="$default_value"
        echo "$prompt_text $input (auto)"
    fi

    input="${input:-$default_value}"
    printf -v "$var_name" '%s' "$input"
}

# --- Check prerequisites ---
check_command() {
    local cmd="$1"
    local install_hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "❌ Required command '$cmd' not found. $install_hint"
        exit 1
    fi
}

check_command kubectl "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
check_command helm "Please install Helm: https://helm.sh/docs/intro/install/"
check_command git "Please install Git: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"

# --- Verify cluster connectivity ---
echo "🌐 Verifying connection to Kubernetes cluster..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Unable to connect to Kubernetes cluster. Possible reasons:"
    echo "   - KUBECONFIG is not set or points to the wrong cluster"
    echo "   - Cluster is unreachable from this host"
    exit 1
fi
echo "✅ Connected to Kubernetes cluster."

# --- Show cluster nodes ---
echo
echo "📋 Listing nodes in the cluster:"
kubectl get nodes --show-labels
echo

# --- Verify at least one node has required label ---
if ! kubectl get nodes -l juno-innovations.com/service=true --no-headers | grep -q .; then
    echo "❌ No nodes in the cluster have the label 'juno-innovations.com/service=true'."
    echo "   Juno's support services require at least one node to have this label."
    echo
    echo "   Example command to label a node:"
    echo "   kubectl label node <NODE_NAME> juno-innovations.com/service=true"
    echo
    exit 1
fi
echo "✅ At least one node has the required Juno label."

# --- Confirm correct cluster ---
prompt CONFIRM "❓ Is this the cluster you want to install to? [y/N]: " "N"
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ Installation aborted by user."
    exit 1
fi

# --- Ensure argocd namespace exists ---
if ! kubectl get namespace argocd >/dev/null 2>&1; then
    echo "⚡ 'argocd' namespace not found. Creating it..."
    kubectl create namespace argocd
    echo "✅ 'argocd' namespace created."
fi

# --- Check if ArgoCD is installed ---
if ! kubectl get deployment -n argocd argocd-server >/dev/null 2>&1; then
    echo "⚡ ArgoCD not detected in 'argocd' namespace. Installing ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo "✅ ArgoCD installation triggered. Waiting for server deployment to be ready..."
    kubectl rollout status deployment/argocd-server -n argocd
fi

# --- Clone repo to temporary directory ---
BRANCH="${BRANCH:-main}"
TMPDIR="$(mktemp -d)"
REPO_URL="https://github.com/juno-fx/Juno-Bootstrap.git"
echo "📥 Cloning branch '$BRANCH' from $REPO_URL into $TMPDIR ..."
git clone --single-branch --branch "$BRANCH" "$REPO_URL" "$TMPDIR"
echo "✅ Repo cloned."

# --- Determine chart path inside cloned repo ---
CHART_DIR="$TMPDIR/chart"
if [[ ! -d "$CHART_DIR" ]]; then
    echo "❌ Chart directory not found at $CHART_DIR"
    exit 1
fi

# --- Determine values files ---
BARE_VALUES="$TMPDIR/deployments/existing-sig/bare/bare.yaml"
if [[ ! -f "$BARE_VALUES" ]]; then
    echo "❌ Bare values file not found at $BARE_VALUES"
    exit 1
fi

USER_VALUES="${VALUES_FILE:-.values.yaml}"
if [[ ! -f "$USER_VALUES" ]]; then
    echo "❌ User values file not found at $USER_VALUES"
    exit 1
fi

echo "✅ Using values files:"
echo "   - Defaults: $BARE_VALUES"
echo "   - Overrides: $USER_VALUES"

# --- Perform Helm install ---
echo
echo "🚀 Performing Helm install into 'argocd' namespace..."
HELM_RELEASE="${HELM_RELEASE:-orion}"

# Install or upgrade via Helm using both -f arguments
if helm status "$HELM_RELEASE" -n argocd >/dev/null 2>&1; then
    echo "🔄 Helm release '$HELM_RELEASE' exists, upgrading..."
    helm upgrade "$HELM_RELEASE" "$CHART_DIR" -f "$BARE_VALUES" -f "$USER_VALUES" -n argocd
else
    echo "📦 Installing Helm release '$HELM_RELEASE'..."
    helm install "$HELM_RELEASE" "$CHART_DIR" -f "$BARE_VALUES" -f "$USER_VALUES" -n argocd
fi

echo "✅ Helm deployment completed successfully!"

# --- Clean up temporary directory ---
rm -rf "$TMPDIR"
echo "🧹 Temporary files cleaned up."
