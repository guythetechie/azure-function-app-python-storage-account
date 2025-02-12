targetScope = 'subscription'

param location string
param tags object = {}
param allowedIpAddressesCsv string = ''

var prefix = 'function-python-${take(uniqueString(subscription().id, '2'), 5)}'
var alphanumericPrefix = replace(prefix, '-', '')

var allowedIpAddresses = empty(allowedIpAddressesCsv)
  ? []
  : map(split(allowedIpAddressesCsv, ','), address => trim(address))

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: '${prefix}-rg'
  location: location
  tags: tags
}

module logAnalyticsWorkspace '../common/bicep/log-analytics-workspace.bicep' = {
  name: 'log-analytics-workspace'
  scope: resourceGroup
  params: {
    name: '${prefix}-log-analytics-workspace'
    location: location
    tags: tags
  }
}

module applicationInsights '../common/bicep/application-insights.bicep' = {
  name: 'application-insights'
  scope: resourceGroup
  params: {
    name: '${prefix}-application-insights'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
  }
}

module storageAccount '../common/bicep/storage-account.bicep' = {
  name: 'storage-account'
  scope: resourceGroup
  params: {
    name: '${alphanumericPrefix}stor'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    allowedIpAddresses: allowedIpAddresses
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

module storageAccountUploadsContainer '../common/bicep/storage-account-container.bicep' = {
  name: 'storage-account-uploads-container'
  scope: resourceGroup
  params: {
    name: 'uploads'
    storageAccountName: storageAccount.outputs.name
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

module storageAccountUploadsQueueDataReaderFunctionAppRoleAssignment '../common/bicep/storage-account-queue-role-assignment.bicep' = {
  name: 'uploads-queue-data-reader-function-app-role-assignment'
  scope: resourceGroup
  params: {
    queueName: storageAccountUploadsQueue.outputs.name
    storageAccountName: storageAccount.outputs.name
    roleName: 'Storage Queue Data Reader'
    principalId: functionApp.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

module storageBlobPrivateDnsZone '../common/bicep/private-dns-zone.bicep' = {
  name: 'storage-blob-private-dns-zone'
  scope: resourceGroup
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    tags: tags
    virtualNetworkId: virtualNetwork.outputs.id
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

module storageQueuePrivateDnsZone '../common/bicep/private-dns-zone.bicep' = {
  name: 'storage-queue-private-dns-zone'
  scope: resourceGroup
  params: {
    name: 'privatelink.queue.${environment().suffixes.storage}'
    tags: tags
    virtualNetworkId: virtualNetwork.outputs.id
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
        name: storageQueuePrivateDnsZone.outputs.name
        id: storageQueuePrivateDnsZone.outputs.id
      }
    ]
    resourceId: storageAccount.outputs.id
    subnetId: privateEndpointSubnet.outputs.id
  }
}

module virtualNetwork '../common/bicep/virtual-network.bicep' = {
  name: 'virtual-network'
  scope: resourceGroup
  params: {
    name: '${prefix}-virtual-network'
    location: location
    tags: tags
    addressPrefixes: [
      '10.0.0.0/24'
    ]
  }
}

module privateEndpointSubnet '../common/bicep/subnet.bicep' = {
  name: 'private-endpoint-subnet'
  scope: resourceGroup
  params: {
    name: 'private-endpoint'
    virtualNetworkName: virtualNetwork.outputs.name
    addressPrefix: '10.0.0.0/28'
  }
}

module vnetIntegrationSubnet '../common/bicep/subnet.bicep' = {
  name: 'vnet-integration-subnet'
  scope: resourceGroup
  params: {
    name: 'vnet-integration'
    virtualNetworkName: virtualNetwork.outputs.name
    addressPrefix: '10.0.0.64/26'
    delegation: 'Microsoft.App/environments'
  }
}

module appServicePlan '../common/bicep/app-service-plan.bicep' = {
  name: 'app-service-plan'
  scope: resourceGroup
  params: {
    name: '${prefix}-app-service-plan'
    location: location
    tags: tags
  }
}

module functionApp '../common/bicep/function-app.bicep' = {
  scope: resourceGroup
  name: 'function-app'
  params: {
    name: '${prefix}-function-app'
    location: location
    tags: tags
    appServicePlanId: appServicePlan.outputs.id
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    storageAccountId: storageAccount.outputs.id
    storageAccountFunctionAppContainerName: storageAccountFunctionAppContainer.outputs.name
    storageAccountUploadsContainerName: storageAccountUploadsContainer.outputs.name
    storageAccountUploadsQueueName: storageAccountUploadsQueue.outputs.name
    vnetIntegrationSubnetId: vnetIntegrationSubnet.outputs.id
  }
}

module eventGridSystemTopic '../common/bicep/event-grid-system-topic.bicep' = {
  name: 'event-grid-system-topic'
  scope: resourceGroup
  params: {
    name: '${prefix}-${storageAccount.outputs.name}-event-grid-system-topic'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.outputs.id
    sourceResourceId: storageAccount.outputs.id
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}

module eventGridSystemTopicSubscription '../common/bicep/event-grid-system-topic-storage-queue-subscription.bicep' = {
  name: 'event-grid-system-topic-subscription'
  scope: resourceGroup
  dependsOn: [
    storageAccountQueueDataMessageSenderSystemTopicRoleAssignment
  ]
  params: {
    name: '${storageAccount.outputs.name}-${storageAccountUploadsQueue.outputs.name}'
    topicName: eventGridSystemTopic.outputs.name
    queueId: storageAccountUploadsQueue.outputs.id
    filter: {
      subjectBeginsWith: '/blobServices/default/containers/${storageAccountUploadsContainer.outputs.name}'
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
      ]
    }
  }
}

output resourceGroupName string = resourceGroup.name
output functionAppName string = functionApp.outputs.name
output storageAccountName string = storageAccount.outputs.name
