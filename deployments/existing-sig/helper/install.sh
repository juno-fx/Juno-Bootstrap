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
kubectl get nodes
echo

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

# --- Perform Helm install ---
echo
echo "🚀 Performing Helm install into 'argocd' namespace..."
HELM_RELEASE="${HELM_RELEASE:-orion}"
VALUES_FILE="${VALUES_FILE:-.values.yaml}"

# Install or upgrade via Helm
if helm status "$HELM_RELEASE" -n argocd >/dev/null 2>&1; then
    echo "🔄 Helm release '$HELM_RELEASE' exists, upgrading..."
    helm upgrade "$HELM_RELEASE" juno-orion/ -f "$VALUES_FILE" -n argocd
else
    echo "📦 Installing Helm release '$HELM_RELEASE'..."
    helm install "$HELM_RELEASE" juno-orion/ -f "$VALUES_FILE" -n argocd
fi

echo "✅ Helm deployment completed successfully!"
