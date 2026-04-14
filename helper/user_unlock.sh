#!/usr/bin/env bash

set -euo pipefail

echo
echo "==============================================================="
echo "   🔑 Official Juno Innovations Basic Account Retrieval Tool"
echo "==============================================================="
echo

read -rp "❓ Which namespace is Genesis deployed under? [argocd]: " NAMESPACE </dev/tty
NAMESPACE="${NAMESPACE:-argocd}"

# Check we have kubectl access
if ! /usr/local/bin/kubectl get pods -n "$NAMESPACE" -l app=genesis -o name &>/dev/null; then
    echo "❌ Failed to access cluster, exiting"
    exit 1
fi

# Check for currently configured accounts and display if found
CURRENT_ACCOUNTS=$(/usr/local/bin/kubectl get pods -n "$NAMESPACE" -l app=genesis -o name | xargs -I {} kubectl get {} -n "$NAMESPACE" -o jsonpath='{.spec.containers[0].env}' | jq -r '.[] | select(.name | startswith("BASIC_AUTH")) | "\(.name): \(.value)"')
if [[ $CURRENT_ACCOUNTS ]]; then
    echo "🔐 Found existing user accounts"
    echo "$CURRENT_ACCOUNTS"
    exit 0
else
    echo "❌ Failed to locate any Basic Accounts configured"
    exit 1
fi
