#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck source=helper/lib.sh
JUNO_BOOTSTRAP_ROOT="${SCRIPT_DIR}/../../../"
source "${JUNO_BOOTSTRAP_ROOT}/helper/lib.sh"

echo
echo "==============================================="
echo "   🚀 Official Juno Innovations Existing Cluster Installer"
echo "==============================================="
echo

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

AWS_REGION=""
# --- Verify EKS Market Place ---
prompt AWS_MARKET_PLACE "🏪 Is the target deployment facilitated by AWS Marketplace? [y/N]: " "N"
if [[ "$AWS_MARKET_PLACE" =~ ^[Yy]$ ]]; then
    check_command aws "Please install aws: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    check_command eksctl "Please install eksctl: https://docs.aws.amazon.com/eks/latest/eksctl/installation.html"

    AWS_REGION="$(aws configure get region)"

    prompt CONFIRM_REGION "❓ We have detect your AWS region as $AWS_REGION, is that correct? [Y/n]: " "y"
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "❌ Please change your region to your required target before continuing, exiting"
        exit 1
    fi

    AWS_VALUES_FILE="./aws/aws.yaml"
    echo "📝 Writing AWS values $AWS_VALUES_FILE..."
    sed \
        -e "s|REPLACE_HELM|911952416775.dkr.ecr.$AWS_REGION.amazonaws.com/cdk-hnb659fds-container-assets-911952416775-$AWS_REGION|g" \
        -e "s|REPLACE_REGISTRY|911952416775.dkr.ecr.$AWS_REGION.amazonaws.com/cdk-hnb659fds-container-assets-911952416775-$AWS_REGION|g" \
        "./aws/aws_template.yaml" > "$AWS_VALUES_FILE"

    echo "✅ $AWS_VALUES_FILE has been updated with your configuration."
    echo
fi

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
    kubectl create -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    echo "✅ ArgoCD installation triggered. Waiting for server deployment to be ready..."
    kubectl rollout status deployment/argocd-server -n argocd
fi



# --- Determine chart path inside cloned repo ---
CHART_DIR="${JUNO_BOOTSTRAP_ROOT}/chart"
if [[ ! -d "$CHART_DIR" ]]; then
    echo "❌ Chart directory not found at $CHART_DIR"
    exit 1
fi

# --- Determine values files ---
BARE_VALUES="${JUNO_BOOTSTRAP_ROOT}/deployments/existing-sig/bare/bare.yaml"
if [[ ! -f "$BARE_VALUES" ]]; then
    echo "❌ Bare values file not found at $BARE_VALUES"
    exit 1
fi

USER_VALUES="${VALUES_FILE:-.values.yaml}"
if [[ ! -f "$USER_VALUES" ]]; then
    echo "❌ User values file not found at $USER_VALUES"
    exit 1
fi

HELM_ARGS=("-f" "$BARE_VALUES" "-f" "$USER_VALUES")

echo "✅ Using values files:"
echo "   - Defaults: $BARE_VALUES"
echo "   - Overrides: $USER_VALUES"

if [[ "$AWS_MARKET_PLACE" =~ ^[Yy]$ ]]; then
    AWS_VALUES="${JUNO_BOOTSTRAP_ROOT}/deployments/existing-sig/aws/aws.yaml"
    if [[ ! -f "$AWS_VALUES" ]]; then
        echo "❌ AWS values file not found at $AWS_VALUES"
        exit 1
    fi
    echo "   - AWS: $AWS_VALUES"
    HELM_ARGS+=("-f" "$AWS_VALUES")
fi

# --- Perform Helm install ---
echo
echo "🚀 Performing Helm install into 'argocd' namespace..."
HELM_RELEASE="${HELM_RELEASE:-orion}"

# Install or upgrade via Helm using both -f arguments
if helm status "$HELM_RELEASE" -n argocd >/dev/null 2>&1; then
    echo "🔄 Helm release '$HELM_RELEASE' exists, upgrading..."
    helm upgrade "$HELM_RELEASE" "$CHART_DIR" "${HELM_ARGS[@]}" -n argocd
else
    echo "📦 Installing Helm release '$HELM_RELEASE'..."
    helm install "$HELM_RELEASE" "$CHART_DIR" "${HELM_ARGS[@]}" -n argocd
fi

echo "✅ Helm deployment completed successfully!"
