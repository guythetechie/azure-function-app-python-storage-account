param name string
param location string
param tags object
param logAnalyticsWorkspaceId string
param allowedIpAddresses array = []

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    networkAcls: {
      bypass: 'AzureServices, Logging, Metrics'
      defaultAction: 'Deny'
      ipRules: map(allowedIpAddresses, address => {
        action: 'Allow'
        value: address
      })
    }
    supportsHttpsTrafficOnly: true
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource blobServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'enable-all'
  scope: blobServices
  properties: {
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
    workspaceId: logAnalyticsWorkspaceId
  }
}

resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource queueServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'enable-all'
  scope: queueServices
  properties: {
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
    workspaceId: logAnalyticsWorkspaceId
  }
}

output name string = storageAccount.name
output id string = storageAccount.id
