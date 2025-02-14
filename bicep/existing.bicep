targetScope = 'subscription'

param applicationName string
param location string
param tags object

import { getPrefix, getAlphanumericPrefix } from '../common/bicep/functions.bicep'

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: toLower('${applicationName}-monitoring-rg')
  location: location
  tags: tags
}

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: toLower('${applicationName}-network-rg')
  location: location
  tags: tags
}

resource uploadsStorageAccountResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: toLower('${applicationName}-uploads-rg')
  location: location
  tags: tags
}

module logAnalyticsWorkspace '../common/bicep/log-analytics-workspace.bicep' = {
  name: 'log-analytics-workspace'
  scope: monitoringResourceGroup
  params: {
    name: '${getPrefix(applicationName, monitoringResourceGroup.id)}-log-analytics-workspace'
    location: location
  }
}

module virtualNetwork '../common/bicep/virtual-network.bicep' = {
  name: 'virtual-network'
  scope: networkResourceGroup
  params: {
    name: '${getPrefix(applicationName, networkResourceGroup.id)}-virtual-network'
    location: location
    addressPrefixes: [
      '10.0.0.0/24'
    ]
    tags: tags
  }
}

module privateEndpointSubnet '../common/bicep/subnet.bicep' = {
  name: 'private-endpoint-subnet'
  scope: networkResourceGroup
  params: {
    name: 'private-endpoint'
    virtualNetworkName: virtualNetwork.outputs.name
    addressPrefix: '10.0.0.0/28'
  }
}

module vnetIntegrationSubnet '../common/bicep/subnet.bicep' = {
  name: 'vnet-integration-subnet'
  scope: networkResourceGroup
  dependsOn: [
    privateEndpointSubnet
  ]
  params: {
    name: 'vnet-integration'
    virtualNetworkName: virtualNetwork.outputs.name
    addressPrefix: '10.0.0.64/26'
    delegation: 'Microsoft.App/environments'
  }
}

module uploadsStorageAccount '../common/bicep/storage-account.bicep' = {
  name: 'uploads-storage-account'
  scope: uploadsStorageAccountResourceGroup
  params: {
    name: '${take(getAlphanumericPrefix(applicationName, uploadsStorageAccountResourceGroup.id), 19)}stor'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module uploadsContainer '../common/bicep/storage-account-container.bicep' = {
  name: 'uploads-container'
  scope: uploadsStorageAccountResourceGroup
  params: {
    name: 'uploads'
    storageAccountName: uploadsStorageAccount.outputs.name
  }
}

module storageBlobPrivateDnsZone '../common/bicep/private-dns-zone.bicep' = {
  name: 'storage-blob-private-dns-zone'
  scope: networkResourceGroup
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    tags: tags
    virtualNetworkId: virtualNetwork.outputs.id
  }
}

module uploadsStorageBlobPrivateEndpoint '../common/bicep/private-endpoint.bicep' = {
  name: 'uploads-storage-blob-private-endpoint'
  scope: uploadsStorageAccountResourceGroup
  params: {
    tags: tags
    group: 'blob'
    location: location
    privateDnsZones: [
      {
        name: storageBlobPrivateDnsZone.outputs.name
        id: storageBlobPrivateDnsZone.outputs.id
      }
    ]
    resourceId: uploadsStorageAccount.outputs.id
    subnetId: privateEndpointSubnet.outputs.id
  }
}

module storageQueuePrivateDnsZone '../common/bicep/private-dns-zone.bicep' = {
  name: 'storage-queue-private-dns-zone'
  scope: networkResourceGroup
  params: {
    name: 'privatelink.queue.${environment().suffixes.storage}'
    tags: tags
    virtualNetworkId: virtualNetwork.outputs.id
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.id
output privateEndpointSubnetId string = privateEndpointSubnet.outputs.id
output vnetIntegrationSubnetId string = vnetIntegrationSubnet.outputs.id
output uploadsStorageAccountContainerId string = uploadsContainer.outputs.id
output storageBlobPrivateDnsZoneId string = storageBlobPrivateDnsZone.outputs.id
output storageQueuePrivateDnsZoneId string = storageQueuePrivateDnsZone.outputs.id
