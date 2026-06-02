#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck source=helper/lib.sh
JUNO_BOOTSTRAP_ROOT="${SCRIPT_DIR}/../../../"
AWS_JUNO_REPO=709825985650
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
echo "📋 Please be aware if AWS marketplace is enabled, changes to your AWS account will be made to allow for licensing of Juno"
# --- Verify EKS marketplace ---
prompt AWS_MARKETPLACE "🏪 Is the target deployment facilitated by AWS Marketplace? [y/N]: " "N"
if [[ "$AWS_MARKETPLACE" =~ ^[Yy]$ ]]; then
    check_command aws "Please install aws: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    check_command eksctl "Please install eksctl: https://docs.aws.amazon.com/eks/latest/eksctl/installation.html"

    AWS_REGION="$(aws configure get region)"
    if [ -z "${AWS_REGION}" ];then
        prompt AWS_REGION "❓ Could not auto detect AWS Region, please enter your region now: " 
    else
        prompt CONFIRM_REGION "❓ We have detect your AWS region as \"$AWS_REGION\", is that correct? [Y/n]: " "y"
        if [[ ! "$CONFIRM_REGION" =~ ^[Yy]$ ]]; then
            echo "❌ Please change your region to your required target before continuing, exiting"
            exit 1
        fi
    fi


    AWS_VALUES_FILE="${JUNO_BOOTSTRAP_ROOT}deployments/existing-sig/aws/aws.yaml"
    echo "📝 Writing AWS values $AWS_VALUES_FILE..."
    sed \
        -e "s|REPLACE_REGISTRY|$AWS_JUNO_REPO.dkr.ecr.$AWS_REGION.amazonaws.com/juno-innovations|g" \
        -e "s|REPLACE_REGION|$AWS_REGION|g" \
        "${JUNO_BOOTSTRAP_ROOT}deployments/existing-sig/aws/aws_template.yaml" > "$AWS_VALUES_FILE"

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

# --- Setup AWS cluster licensing ---
if [[ "$AWS_MARKETPLACE" =~ ^[Yy]$ ]]; then
    CLUSTERS=$(eksctl get cluster | awk 'NR>1 {print $1}' | paste -s -d, -)
    CURRENT_CONTEXT=$(kubectl config view --minify --output jsonpath='{.clusters[0].name}' | awk -F'/' '{print $NF}')
    echo "📜 Setting up license IAM policy"
    echo "- Detected EKS clusters: $CLUSTERS"
    CLUSTER=""

    if [[ "$CLUSTERS" == *"$CURRENT_CONTEXT"* ]]; then
       prompt CLUSTER "🖧 Please enter which EKS cluster to setup [$CURRENT_CONTEXT]: " "$CURRENT_CONTEXT"
    else
       prompt CLUSTER "🖧 Please enter which EKS cluster to setup: "
    fi

    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    CONSUME_POLICY_NAME=genesis-license-consume-policy-$CLUSTER
    CONSUME_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${CONSUME_POLICY_NAME}"
    CONSUME_POLICY_CREATE=true
    if aws iam get-policy --policy-arn "$CONSUME_POLICY_ARN" > /dev/null 2>&1; then
        prompt RECREATE "Consume policy already exists, force recreate? [y/N]: " "N"
        if [[ "$RECREATE" =~ ^[Yy]$ ]]; then
            aws iam delete-policy --policy-arn "$CONSUME_POLICY_ARN" 2>/dev/null
         else
            CONSUME_POLICY_CREATE=false
        fi
    fi

    echo "- Setting up IAM policies for Juno licensing"
    if [ "$CONSUME_POLICY_CREATE" = true ]; then
        CONSUME_POLICY_ARN=$(aws iam create-policy \
            --policy-name "$CONSUME_POLICY_NAME" \
            --policy-document '{
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Sid": "VisualEditor0",
                        "Effect": "Allow",
                        "Action": [
                            "license-manager:CheckoutLicense",
                            "license-manager:CheckInLicense",
                            "license-manager:ExtendLicenseConsumption",
                            "license-manager:GetLicense",
                            "license-manager:GetLicenseUsage"
                        ],
                        "Resource": "*"
                    }
                ]
            }' \
            --query 'Policy.Arn' \
            --output text)
    fi

    LIST_POLICY_NAME=genesis-license-list-policy-$CLUSTER
    LIST_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${LIST_POLICY_NAME}"
    LIST_POLICY_CREATE=true
    if aws iam get-policy --policy-arn "$LIST_POLICY_ARN" > /dev/null 2>&1; then
        prompt RECREATE "List policy already exists, force recreate? [y/N]: " "N"
        if [[ "$RECREATE" =~ ^[Yy]$ ]]; then
            aws iam delete-policy --policy-arn "$LIST_POLICY_ARN" 2>/dev/null
        else
            LIST_POLICY_CREATE=false
        fi
    fi

    if [ "$LIST_POLICY_CREATE" = true ]; then
        LIST_POLICY_ARN=$(aws iam create-policy \
            --policy-name "$LIST_POLICY_NAME" \
            --policy-document '{
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Sid": "VisualEditor0",
                        "Effect": "Allow",
                        "Action": [
                        "license-manager:ListReceivedLicenses"
                        ],
                        "Resource": "*"
                    }
                ]
            }' \
            --query 'Policy.Arn' \
            --output text)
    fi

    OVERRIDE=""
    CREATE_SA=true
    if eksctl get iamserviceaccount --cluster "$CLUSTER" --namespace argocd 2>/dev/null | grep -w "genesis" > /dev/null 2>&1; then
        prompt RECREATE "IAM service account already exists, force recreate? [y/N]: " "N"
        if [[ "$RECREATE" =~ ^[Yy]$ ]]; then
            OVERRIDE="--override-existing-serviceaccounts"
        else
            CREATE_SA=false
        fi
    fi

    if [ "$CREATE_SA" = true ]; then
        echo "Creating/Updating Service IAM account 'genesis'..."
        # Evaluated $OVERRIDE inline so it applies correctly when string is empty or populated
        eksctl create iamserviceaccount \
            --name genesis \
            --namespace argocd \
            --cluster "$CLUSTER" \
            --attach-policy-arn "$LIST_POLICY_ARN" \
            --attach-policy-arn "$CONSUME_POLICY_ARN" \
            $OVERRIDE \
            --approve
    fi
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

if [[ "$AWS_MARKETPLACE" =~ ^[Yy]$ ]]; then
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
