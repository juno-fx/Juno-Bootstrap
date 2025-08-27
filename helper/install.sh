#!/usr/bin/env bash

set -euo pipefail

echo
echo "==============================================="
echo "   🚀 Official Juno Innovations One Click Orion Installer"
echo "==============================================="
echo

# Branch handling
BRANCH="${BRANCH:-main}"
echo "📌 Using branch: $BRANCH"

# Download .values.yaml if not already present
VALUES_FILE=".values.yaml"
if [[ -f "$VALUES_FILE" ]]; then
    echo "📄 Found existing $VALUES_FILE — skipping download."
else
    echo "📥 Downloading values.yaml from branch: $BRANCH ..."
    curl -fsSL -o "$VALUES_FILE" "https://raw.githubusercontent.com/juno-fx/Juno-Bootstrap/refs/heads/$BRANCH/helper/values.yaml"
    echo "✅ values.yaml downloaded as $VALUES_FILE"
fi
echo

# Prompt for user inputs
read -rp "🌐 Enter the hostname (DNS only, no IPs) for the server: " HOSTNAME
if [[ "$HOSTNAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Error: IP addresses are not allowed. Must be a DNS hostname."
    exit 1
fi

read -rp "📧 Enter the owner email: " OWNER_EMAIL

read -rsp "🔑 Enter the default temporary password for the owner: " OWNER_PASSWORD
echo

while true; do
    read -rp "👤 Enter the username (letters only): " USERNAME
    if [[ "$USERNAME" =~ ^[A-Za-z]+$ ]]; then
        break
    else
        echo "❌ Invalid username. Must contain only letters (A–Z, a–z)."
    fi
done

read -rp "🆔 Enter the UID for that user: " USER_UID

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
