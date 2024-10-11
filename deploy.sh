#!/bin/bash
# Might need to run chmod +rx deploy.sh to make the script executable

# shellcheck disable=SC3040
set -euo -pipefail

echo "Prompting user for parameters..."
# shellcheck disable=SC3045
read -r -p "Enter your location: " AZURE_LOCATION

echo "Login to Azure if the user is not already logged in..."
if ! az account show; then
    az login --use-device-code
fi

echo "Deploying resources..."
az stack sub create \
    --action-on-unmanage deleteAll \
    --name "deploy-python-function-app2" \
    --deny-settings-mode none \
    --location "$AZURE_LOCATION" \
    --template-file "./bicep/main.bicep" \
    --parameters location="$AZURE_LOCATION" \
    --parameters allowedIpAddress="$(curl -s ipinfo.io/ip)"
