#!/bin/bash

set -euo -pipefail

pwsh -Command '{Install-Module -Name Az -Force -Confirm:$False -Force}'