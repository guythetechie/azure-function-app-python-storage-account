using 'main.bicep'

param location = readEnvironmentVariable('AZURE_LOCATION', '')
param allowedIpAddressesSring = readEnvironmentVariable('ALLOWED_IP_ADDRESSES', '')
