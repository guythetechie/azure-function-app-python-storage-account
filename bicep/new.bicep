targetScope = 'subscription'

param applicationName string
param location string
param tags object
param logAnalyticsWorkspaceId string
param virtualNetworkId string

import {
  getPrefix
  getAlphanumericPrefix
  getResourceName
  getResourceGroupName
  getResourceParentId
  getResourceParentName
} from '../common/bicep/functions.bicep'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: toLower('${applicationName}-rg')
  location: location
  tags: tags
}

resource networkResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  name: getResourceGroupName(virtualNetworkId)
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: getResourceName(virtualNetworkId)
  scope: networkResourceGroup
}

module privateEndpointSubnet '../common/bicep/subnet.bicep' = {
  name: 'private-endpoint-subnet'
  scope: networkResourceGroup
  params: {
    name: 'private-endpoint'
    virtualNetworkName: virtualNetwork.name
    addressPrefix: '172.28.169.0/28'
  }
}

module dnsResolverOutboundSubnet '../common/bicep/subnet.bicep' = {
  name: 'dns-resolver-outbound-subnet'
  dependsOn: [
    privateEndpointSubnet
  ]
  scope: networkResourceGroup
  params: {
    name: 'dns-resolver-outbound'
    virtualNetworkName: virtualNetwork.name
    addressPrefix: '172.28.169.32/28'
    delegation: 'Microsoft.Network/dnsResolvers'
  }
}

module vnetIntegrationSubnet '../common/bicep/subnet.bicep' = {
  name: 'vnet-integration-subnet'
  scope: networkResourceGroup
  dependsOn: [
    dnsResolverOutboundSubnet
  ]
  params: {
    name: 'vnet-integration'
    virtualNetworkName: virtualNetwork.name
    addressPrefix: '172.28.169.64/27'
    delegation: 'Microsoft.App/environments'
  }
}

module applicationInsights '../common/bicep/application-insights.bicep' = {
  name: 'application-insights'
  scope: resourceGroup
  params: {
    name: '${getPrefix(applicationName, resourceGroup.id)}-application-insights'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module storageBlobPrivateDnsZone '../common/bicep/private-dns-zone.bicep' = {
  name: 'storage-blob-private-dns-zone'
  scope: networkResourceGroup
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    tags: tags
    virtualNetworkId: virtualNetwork.id
  }
}

module storageAccount '../common/bicep/storage-account.bicep' = {
  name: 'storage-account'
  scope: resourceGroup
  params: {
    name: toLower('${take(getAlphanumericPrefix(applicationName, resourceGroup.id), 19)}stor')
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module storageAccountFunctionAppContainer '../common/bicep/storage-account-container.bicep' = {
  name: 'storage-account-function-app-container'
  scope: resourceGroup
  params: {
    name: 'function-app'
    storageAccountName: storageAccount.outputs.name
  }
}

module storageAccountBlobDataOwnerFunctionAppRoleAssignment '../common/bicep/storage-account-role-assignment.bicep' = {
  name: 'storage-account-blob-data-owner-function-app-role-assignment'
  scope: resourceGroup
  params: {
    principalId: functionApp.outputs.principalId
    storageAccountName: storageAccount.outputs.name
    roleName: 'Storage Blob Data Owner'
    principalType: 'ServicePrincipal'
  }
}

module storageBlobPrivateEndpoint '../common/bicep/private-endpoint.bicep' = {
  name: 'storage-blob-private-endpoint'
  scope: resourceGroup
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
    resourceId: storageAccount.outputs.id
    subnetId: privateEndpointSubnet.outputs.id
  }
}

module appServicePlan '../common/bicep/app-service-plan.bicep' = {
  name: 'app-service-plan'
  scope: resourceGroup
  params: {
    name: '${getPrefix(applicationName, resourceGroup.id)}-app-service-plan'
    location: location
    tags: tags
  }
}

module functionApp '../common/bicep/function-app.bicep' = {
  scope: resourceGroup
  name: 'function-app'
  params: {
    name: '${getAlphanumericPrefix(applicationName, resourceGroup.id)}-function-app'
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    storageAccountId: storageAccount.outputs.id
    storageAccountFunctionAppContainerName: storageAccountFunctionAppContainer.outputs.name
    vnetIntegrationSubnetId: vnetIntegrationSubnet.outputs.id
  }
}
