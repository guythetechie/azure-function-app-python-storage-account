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

resource uploadsResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
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
      '172.28.169.0/24'
    ]
    tags: tags
  }
}

// module privateEndpointSubnet '../common/bicep/subnet.bicep' = {
//   name: 'private-endpoint-subnet'
//   scope: networkResourceGroup
//   params: {
//     name: 'private-endpoint'
//     virtualNetworkName: virtualNetwork.outputs.name
//     addressPrefix: '10.0.0.0/28'
//   }
// }

// module vnetIntegrationSubnet '../common/bicep/subnet.bicep' = {
//   name: 'vnet-integration-subnet'
//   scope: networkResourceGroup
//   dependsOn: [
//     privateEndpointSubnet
//   ]
//   params: {
//     name: 'vnet-integration'
//     virtualNetworkName: virtualNetwork.outputs.name
//     addressPrefix: '10.0.0.64/26'
//     delegation: 'Microsoft.App/environments'
//   }
// }

module uploadsStorageAccount '../common/bicep/storage-account.bicep' = {
  name: 'uploads-storage-account'
  scope: uploadsResourceGroup
  params: {
    name: '${take(getAlphanumericPrefix(applicationName, uploadsResourceGroup.id), 19)}uploadstor'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module uploadsContainer '../common/bicep/storage-account-container.bicep' = {
  name: 'uploads-container'
  scope: uploadsResourceGroup
  params: {
    name: 'uploads'
    storageAccountName: uploadsStorageAccount.outputs.name
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.id
output virtualNetworkId string = virtualNetwork.outputs.id
output uploadsStorageAccountContainerId string = uploadsContainer.outputs.id
