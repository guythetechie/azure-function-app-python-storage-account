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
    privateEndpointSubnetId: existing.outputs.privateEndpointSubnetId
    storageBlobPrivateDnsZoneId: existing.outputs.storageBlobPrivateDnsZoneId
    storageQueuePrivateDnsZoneId: existing.outputs.storageQueuePrivateDnsZoneId
    uploadsStorageAccountContainerId: existing.outputs.uploadsStorageAccountContainerId
    vnetIntegrationSubnetId: existing.outputs.vnetIntegrationSubnetId
  }
}
