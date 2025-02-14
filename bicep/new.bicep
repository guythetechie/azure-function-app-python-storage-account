targetScope = 'subscription'

param applicationName string
param location string
param tags object
param uploadsStorageAccountContainerId string
param logAnalyticsWorkspaceId string
param privateEndpointSubnetId string
param vnetIntegrationSubnetId string
param storageBlobPrivateDnsZoneId string
param storageQueuePrivateDnsZoneId string

import {
  getPrefix
  getAlphanumericPrefix
  getResourceName
  getResourceGroupName
  getResourceParentId
  getResourceParentName
} from '../common/bicep/functions.bicep'

var uploadsStorageAccountContainerName = getResourceName(uploadsStorageAccountContainerId)

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: toLower('${applicationName}-rg')
  location: location
  tags: tags
}

resource uploadsStorageAccountResourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  name: getResourceGroupName(uploadsStorageAccountContainerId)
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
        name: getResourceName(storageBlobPrivateDnsZoneId)
        id: storageBlobPrivateDnsZoneId
      }
    ]
    resourceId: storageAccount.outputs.id
    subnetId: privateEndpointSubnetId
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
        name: getResourceName(storageQueuePrivateDnsZoneId)
        id: storageQueuePrivateDnsZoneId
      }
    ]
    resourceId: storageAccount.outputs.id
    subnetId: privateEndpointSubnetId
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
    storageAccountUploadsQueueName: storageAccountUploadsQueue.outputs.name
    vnetIntegrationSubnetId: vnetIntegrationSubnetId
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
      subjectBeginsWith: '/blobServices/default/containers/${uploadsStorageAccountContainerName}'
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
      ]
    }
  }
}
