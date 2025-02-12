#!/bin/bash

set -euo -pipefail

# WORKSPACES_FOLDER=$(dirname "$(realpath "$0")")
WORKSPACES_FOLDER="/workspaces/azure-function-app-python-storage-account"
FUNCTION_APP_FOLDER="$WORKSPACES_FOLDER/src/functionapp"
python3 -m venv "$FUNCTION_APP_FOLDER/.venv"
source "$FUNCTION_APP_FOLDER/.venv/bin/activate"
python3 -m pip install -r "$FUNCTION_APP_FOLDER/requirements.txt"