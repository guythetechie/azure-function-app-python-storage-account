targetScope = 'subscription'

param applicationName string
param location string
param tags object = {}

module existing 'existing.bicep' = {
  name: 'existing'
  params: {
    applicationName: applicationName
    location: location
    tags: tags
  }
}

module new 'new.bicep' = {
  name: 'new'
  params: {
    location: location
    tags: tags
    applicationName: applicationName
    logAnalyticsWorkspaceId: existing.outputs.logAnalyticsWorkspaceId
    uploadsStorageAccountContainerId: existing.outputs.uploadsStorageAccountContainerId
    virtualNetworkId: existing.outputs.virtualNetworkId
  }
}
