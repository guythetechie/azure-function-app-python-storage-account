targetScope = 'subscription'

import {
  getPrefix
  getAlphanumericPrefix
  getResourceName
  getResourceGroupName
  getResourceParentId
  getResourceParentName
} from '../common/bicep/functions.bicep'

import {
  DnsForwardingRule
} from '../common/bicep/types.bicep'

param applicationName string
param location string
param tags object
param logAnalyticsWorkspaceId string
param virtualNetworkId string
param forwardingRules DnsForwardingRule[] = []
param uploadsStorageAccountContainerId string
param blobNameFilter string?

var uploadsStorageAccountContainerName = getResourceName(uploadsStorageAccountContainerId)

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

resource uploadsStorageAccountResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  name: getResourceGroupName(uploadsStorageAccountContainerId)
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

module storageQueuePrivateDnsZone '../common/bicep/private-dns-zone.bicep' = {
  name: 'storage-queue-private-dns-zone'
  scope: networkResourceGroup
  params: {
    name: 'privatelink.queue.${environment().suffixes.storage}'
    tags: tags
    virtualNetworkId: virtualNetwork.id
  }
}

module appServicePrivateDnsZone '../common/bicep/private-dns-zone.bicep' = {
  name: 'app-service-private-dns-zone'
  scope: networkResourceGroup
  params: {
    name: 'privatelink.azurewebsites.net'
    tags: tags
    virtualNetworkId: virtualNetwork.id
  }
}

module storageAccount '../common/bicep/storage-account.bicep' = {
  name: 'storage-account'
  scope: resourceGroup
  params: {
    name: '${take(getAlphanumericPrefix(applicationName, resourceGroup.id), 19)}stor'
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

module storageAccountUploadsQueue '../common/bicep/storage-account-queue.bicep' = {
  name: 'storage-account-blob-queue'
  scope: resourceGroup
  params: {
    name: 'uploads'
    storageAccountName: storageAccount.outputs.name
  }
}

module storageQueuePrivateEndpoint '../common/bicep/private-endpoint.bicep' = {
  name: 'storage-queue-private-endpoint'
  scope: resourceGroup
  params: {
    tags: tags
    group: 'queue'
    location: location
    privateDnsZones: [
      {
        name: getResourceName(storageQueuePrivateDnsZone.outputs.id)
        id: storageQueuePrivateDnsZone.outputs.id
      }
    ]
    resourceId: storageAccount.outputs.id
    subnetId: privateEndpointSubnet.outputs.id
  }
}

module storageAccountUploadsQueueDataReaderFunctionAppRoleAssignment '../common/bicep/storage-account-queue-role-assignment.bicep' = {
  name: 'uploads-queue-data-reader-function-app-role-assignment'
  scope: resourceGroup
  params: {
    queueName: storageAccountUploadsQueue.outputs.name
    storageAccountName: storageAccount.outputs.name
    roleName: 'Storage Queue Data Contributor'
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

module storageAccountQueueDataMessageSenderSystemTopicRoleAssignment '../common/bicep/storage-account-role-assignment.bicep' = {
  name: 'queue-data-message-sender-system-topic-role-assignment'
  scope: resourceGroup
  params: {
    storageAccountName: storageAccount.outputs.name
    roleName: 'Storage Queue Data Message Sender'
    principalId: eventGridSystemTopic.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

resource uploadsStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: getResourceParentName(getResourceParentId(uploadsStorageAccountContainerId))
  scope: uploadsStorageAccountResourceGroup
}

module uploadsStorageContainerBlobDataReaderRoleAssignment '../common/bicep/storage-account-container-role-assignment.bicep' = {
  name: 'uploads-storage-container-blob-data-reader-role-assignment'
  scope: uploadsStorageAccountResourceGroup
  params: {
    containerName: uploadsStorageAccountContainerName
    storageAccountName: uploadsStorageAccount.name
    roleName: 'Storage Blob Data Reader'
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
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
    name: '${getPrefix(applicationName, resourceGroup.id)}-function-app'
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    storageAccountId: storageAccount.outputs.id
    storageAccountFunctionAppContainerName: storageAccountFunctionAppContainer.outputs.name
    storageAccountUploadsQueueName: storageAccountUploadsQueue.outputs.name
    vnetIntegrationSubnetId: vnetIntegrationSubnet.outputs.id
  }
}

module functionAppPrivateEndpoint '../common/bicep/private-endpoint.bicep' = {
  name: 'function-app-private-endpoint'
  scope: resourceGroup
  params: {
    tags: tags
    group: 'sites'
    location: location
    privateDnsZones: [
      {
        name: appServicePrivateDnsZone.outputs.name
        id: appServicePrivateDnsZone.outputs.id
      }
    ]
    resourceId: functionApp.outputs.id
    subnetId: privateEndpointSubnet.outputs.id
  }
}

module dnsResolver '../common/bicep/dns-resolver.bicep' = {
  name: 'dns-resolver'
  scope: resourceGroup
  params: {
    name: '${getPrefix(applicationName, resourceGroup.id)}-dns-resolver'
    location: location
    tags: tags
    virtualNetworkId: virtualNetwork.id
    outboundEndpointSubnetId: dnsResolverOutboundSubnet.outputs.id
  }
}

module dnsForwardingRule '../common/bicep/dns-forwarding-ruleset.bicep' = {
  name: 'dns-forwarding-ruleset'
  scope: resourceGroup
  params: {
    name: '${getPrefix(applicationName, resourceGroup.id)}-dns-forwarding-ruleset'
    location: location
    tags: tags
    virtualNetworkIds: [virtualNetwork.id]
    rules: forwardingRules
    dnsResolverOutboundEndpointId: dnsResolver.outputs.outboundEndpointId
  }
}

module eventGridSystemTopic '../common/bicep/event-grid-system-topic.bicep' = {
  name: 'event-grid-system-topic'
  scope: uploadsStorageAccountResourceGroup
  params: {
    name: '${getAlphanumericPrefix(applicationName, resourceGroup.id)}-event-grid-system-topic'
    location: uploadsStorageAccount.location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    sourceResourceId: uploadsStorageAccount.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

module eventGridSystemTopicSubscription '../common/bicep/event-grid-system-topic-storage-queue-subscription.bicep' = {
  name: 'event-grid-system-topic-subscription'
  scope: uploadsStorageAccountResourceGroup
  dependsOn: [
    storageAccountQueueDataMessageSenderSystemTopicRoleAssignment
  ]
  params: {
    name: '${storageAccount.outputs.name}-${storageAccountUploadsQueue.outputs.name}'
    topicName: eventGridSystemTopic.outputs.name
    queueId: storageAccountUploadsQueue.outputs.id
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${uploadsStorageAccountContainerName}${empty(blobNameFilter) ? '' : '/blobs/${blobNameFilter}'}'
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
      ]
    }
  }
}
