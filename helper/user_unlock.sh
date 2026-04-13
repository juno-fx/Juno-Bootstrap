#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# shellcheck source=helper/lib.sh
source "${SCRIPT_DIR}/lib.sh"

echo
echo "==============================================="
echo "   🔑 Official Juno Innovations Account Unlock Tool"
echo "==============================================="
echo

# Check if we have access to kubectl

KUBE_ACCESS=$(/usr/local/bin/kubectl get pods -n argocd -l app=genesis -o name)
if [[ "$KUBE_ACCESS" -gt 0 ]]; then
    echo "❌ Failed to access cluster, exiting"
    exit 1
fi

CURRENT_ACCOUNTS=$(kubectl get pods -n argocd -l app=genesis -o name | xargs -I {} kubectl get {} -n argocd -o jsonpath='{.spec.containers[0].env}' | jq -r '.[] | select(.name | startswith("BASIC_AUTH")) | "\(.name): \(.value)"')
if [[ $CURRENT_ACCOUNTS ]]; then
    echo "🔐 Found existing user accounts"
    echo "$CURRENT_ACCOUNTS"
    exit 0
fi

prompt NAMESPACE "❓ Which namespace is Genesis deployed under? [argocd]: " "argocd"
NEW_PASSWORD="CHANGE_ME"

# Get current values preserving newlines
CURRENT_VALUES=$(kubectl get application genesis -n "$NAMESPACE" \
  -o json | jq -r '.spec.sources[0].helm.values')

# Extract titan.email
NEW_EMAIL=$(echo "$CURRENT_VALUES" | grep -A1 "^titan:" | grep "email:" | awk '{print $2}')

if [[ ! $NEW_EMAIL ]]; then
    echo "❌ Could not determine email address"
    prompt NEW_EMAIL "🔍 Enter original email address used during install: "
    if [[ ! $NEW_EMAIL ]]; then
        echo "❌ No email address entered, exiting"
        exit 1
    fi
fi

NEW_ENTRY=" BASIC_AUTH_EMAIL: ${NEW_EMAIL}"$'\n'" BASIC_AUTH_PASSWORD: ${NEW_PASSWORD}"

# Check if there is already an "env" section and handle it accordingly
if echo "$CURRENT_VALUES" | grep -q "^env:"; then
 NEW_VALUES=$(echo "$CURRENT_VALUES" | awk -v email=" BASIC_AUTH_EMAIL_${NEW_INDEX}: ${NEW_EMAIL}" -v password=" BASIC_AUTH_PASSWORD_${NEW_INDEX}: ${NEW_PASSWORD}" '/^env:/{print; print email; print password; next}1')
else
  NEW_VALUES="env:"$'\n'"${NEW_ENTRY}"$'\n'"${CURRENT_VALUES}"
fi

PATCH=$(jq -n --arg vals "$NEW_VALUES" '[
  {
    "op": "replace",
    "path": "/spec/sources/0/helm/values",
    "value": $vals
  }
]')

kubectl patch application genesis -n "$NAMESPACE" \
  --type='json' \
  -p "$PATCH"

echo "User account reset:"
echo "👤   Username: $NEW_EMAIL"
echo "🔑   Password: $NEW_PASSWORD"

