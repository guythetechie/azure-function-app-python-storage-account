using 'main.bicep'

param location = readEnvironmentVariable('AZURE_LOCATION', '')
param allowedIpAddressesCsv = readEnvironmentVariable('ALLOWED_IP_ADDRESSES', '')
