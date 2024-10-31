targetScope = 'subscription'

param location string
param tags object = {}
param prefix string = 'pmobidl${take(uniqueString(subscription().id, '2'), 6)}'
param resourceGroupName string = '${prefix}-rg'
param logAnalyticsWorkspaceName string = '${prefix}-law'
param applicationInsightsName string = '${prefix}-appinsights'
param virtualNetworkName string = '${prefix}-vnet'
param privateEndpointSubnetName string = 'private-endpoint-subnet'
param vnetIntegrationSubnetName string = 'vnet-integration-subnet'
param storageAccountName string = '${prefix}stor'
param storageAccountContainerName string = 'blobs-container'
param storageAccountQueueName string = 'blobs'
param functionAppName string = '${prefix}-funcapp'
param eventGridTopicName string = '${storageAccountName}-topic'
param allowedIpAddressesSring string = ''

var allowedIpAddresses = map(split(allowedIpAddressesSring, ','), address => trim(address))

resource storageQueueDataMessageSenderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
  scope: subscription()
}

resource storageQueueDataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '19e7f393-937e-4f77-808e-94535e297925'
  scope: subscription()
}

resource storageBlobDataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
}

module resourceGroupDeployment 'br/public:avm/res/resources/resource-group:0.4.0' = {
  scope: subscription()
  name: 'resource-group-deployment'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' existing = {
  name: resourceGroupName
}

module logAnalyticsWorkspaceDeployment 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  scope: resourceGroup
  name: 'log-analytics-workspace-deployment'
  dependsOn: [resourceGroupDeployment]
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    tags: tags
    skuName: 'PerGB2018'
    dataRetention: 30
  }
}

module applicationInsightsDeployment 'br/public:avm/res/insights/component:0.3.0' = {
  scope: resourceGroup
  name: 'application-insights-deployment'
  params: {
    name: applicationInsightsName
    location: location
    tags: tags
    workspaceResourceId: logAnalyticsWorkspaceDeployment.outputs.resourceId
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
  scope: resourceGroup
}

module virtualNetworkDeployment 'br/public:avm/res/network/virtual-network:0.4.0' = {
  scope: resourceGroup
  dependsOn: [resourceGroupDeployment]
  name: 'virtual-network-deployment'
  params: {
    name: virtualNetworkName
    location: location
    tags: tags
    addressPrefixes: [
      '10.0.0.0/24'
    ]
    subnets: [
      {
        name: privateEndpointSubnetName
        addressPrefix: '10.0.0.0/26'
      }
      {
        name: vnetIntegrationSubnetName
        addressPrefix: '10.0.0.64/26'
        delegation: 'Microsoft.App/environments'
      }
    ]
  }
}

module blobPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.6.0' = {
  scope: resourceGroup
  name: 'blob-private-dns-zone-deployment'
  dependsOn: [resourceGroupDeployment]
  params: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: virtualNetworkDeployment.outputs.name
        virtualNetworkResourceId: virtualNetworkDeployment.outputs.resourceId
      }
    ]
  }
}

module queuePrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.6.0' = {
  scope: resourceGroup
  name: 'queue-private-dns-zone-deployment'
  dependsOn: [resourceGroupDeployment]
  params: {
    name: 'privatelink.queue.${environment().suffixes.storage}'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
        name: virtualNetworkDeployment.outputs.name
        virtualNetworkResourceId: virtualNetworkDeployment.outputs.resourceId
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  scope: resourceGroup
  name: virtualNetworkName
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  parent: virtualNetwork
  name: privateEndpointSubnetName
}

resource vnetIntegrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  parent: virtualNetwork
  name: vnetIntegrationSubnetName
}

module storageAccountDeployment 'br/public:avm/res/storage/storage-account:0.14.1' = {
  scope: resourceGroup
  name: 'storage-account-deployment'
  dependsOn: [
    resourceGroupDeployment
    virtualNetworkDeployment
  ]
  params: {
    name: storageAccountName
    location: location
    tags: tags
    skuName: 'Standard_LRS'
    privateEndpoints: [
      {
        name: '${storageAccountName}-blob-pep'
        service: 'blob'
        subnetResourceId: privateEndpointSubnet.id
        customNetworkInterfaceName: '${storageAccountName}-nic'
        tags: tags
        privateLinkServiceConnectionName: '${storageAccountName}-blob'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              name: blobPrivateDnsZone.outputs.name
              privateDnsZoneResourceId: blobPrivateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
    networkAcls: {
      bypass: 'AzureServices, Logging, Metrics'
      defaultAction: 'Deny'
      ipRules: empty(allowedIpAddresses)
        ? null
        : map(allowedIpAddresses, address => {
            action: 'Allow'
            value: address
          })
    }
    blobServices: {
      containers: [
        {
          name: storageAccountContainerName
          publicAccess: 'None'
        }
      ]
      diagnosticSettings: [
        {
          name: 'enable-all'
          logAnalyticsDestinationType: 'Dedicated'
          logCategoriesAndGroups: [
            {
              categoryGroup: 'AllLogs'
            }
          ]
          workspaceResourceId: logAnalyticsWorkspaceDeployment.outputs.resourceId
        }
      ]
    }
    queueServices: {
      queues: [
        {
          name: storageAccountQueueName
        }
      ]
      diagnosticSettings: [
        {
          name: 'enable-all'
          logAnalyticsDestinationType: 'Dedicated'
          logCategoriesAndGroups: [
            {
              categoryGroup: 'AllLogs'
            }
          ]
          workspaceResourceId: logAnalyticsWorkspaceDeployment.outputs.resourceId
        }
      ]
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
  scope: resourceGroup
}

resource storageAccountBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource storageAccountContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  name: storageAccountContainerName
  parent: storageAccountBlobService
}

resource storageAccountQueueService 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource storageAccountQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' existing = {
  name: storageAccountQueueName
  parent: storageAccountQueueService
}

module appServicePlanDeployment 'br/public:avm/res/web/serverfarm:0.2.4' = {
  scope: resourceGroup
  dependsOn: [resourceGroupDeployment]
  name: 'app-service-plan-deployment'
  params: {
    name: '${functionAppName}-plan'
    location: location
    tags: tags
    kind: 'FunctionApp'
    skuName: 'FC1'
    reserved: true
  }
}

module functionAppDeployment 'br/public:avm/res/web/site:0.10.0' = {
  scope: resourceGroup
  name: 'function-app-deployment'
  dependsOn: [
    resourceGroupDeployment
    virtualNetworkDeployment
    storageAccountDeployment
    applicationInsightsDeployment
  ]
  params: {
    name: functionAppName
    location: location
    tags: tags
    kind: 'functionapp,linux'
    managedIdentities: {
      systemAssigned: true
    }
    serverFarmResourceId: appServicePlanDeployment.outputs.resourceId
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: storageAccount.properties.primaryEndpoints.queue
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: storageAccount.properties.primaryEndpoints.table
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'STORAGE_ACCOUNT_CONNECTION__blobServiceUri'
          value: storageAccount.properties.primaryEndpoints.blob
        }
        {
          name: 'STORAGE_ACCOUNT_CONNECTION__queueServiceUri'
          value: storageAccount.properties.primaryEndpoints.queue
        }
        {
          name: 'STORAGE_ACCOUNT_CONTAINER_NAME'
          value: storageAccountContainerName
        }
        {
          name: 'STORAGE_ACCOUNT_QUEUE_NAME'
          value: storageAccountQueueName
        }
      ]
      cors: {
        allowedOrigins: [
          'https://portal.azure.com'
        ]
      }
    }
    vnetRouteAllEnabled: false
    vnetContentShareEnabled: true
    vnetImagePullEnabled: true
    virtualNetworkSubnetId: vnetIntegrationSubnet.id
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: uri(storageAccountDeployment.outputs.primaryBlobEndpoint, storageAccountContainerName)
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'python'
        version: '3.11'
      }
    }
  }
}

module eventGridSystemTopicDeployment 'br/public:avm/res/event-grid/system-topic:0.4.0' = {
  scope: resourceGroup
  name: 'event-grid-system-topic-deployment'
  params: {
    name: eventGridTopicName
    location: location
    tags: tags
    managedIdentities: {
      systemAssigned: true
    }
    source: storageAccountDeployment.outputs.resourceId
    topicType: 'Microsoft.Storage.StorageAccounts'
    diagnosticSettings: [
      {
        name: 'enable-all'
        logAnalyticsDestinationType: 'Dedicated'
        logCategoriesAndGroups: [
          {
            categoryGroup: 'AllLogs'
          }
        ]
        workspaceResourceId: logAnalyticsWorkspaceDeployment.outputs.resourceId
      }
    ]
  }
}

module eventGridStorageAccountRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  name: 'event-grid-service-bus-role-assignment'
  params: {
    principalId: eventGridSystemTopicDeployment.outputs.systemAssignedMIPrincipalId
    resourceId: storageAccountQueue.id
    roleDefinitionId: storageQueueDataMessageSenderRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

module functionAppStorageAccountRoleAssignments 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = [
  for (item, index) in [
    {
      resourceId: storageAccountContainer.id
      roleDefinitionId: storageBlobDataReaderRoleDefinition.id
    }
    {
      resourceId: storageAccountQueue.id
      roleDefinitionId: storageQueueDataReaderRoleDefinition.id
    }
  ]: {
    scope: resourceGroup
    name: 'function-app-storage-account-role-assignment-${index}'
    dependsOn: [
      storageAccountDeployment
    ]
    params: {
      principalId: functionAppDeployment.outputs.systemAssignedMIPrincipalId
      resourceId: item.resourceId
      roleDefinitionId: item.roleDefinitionId
      principalType: 'ServicePrincipal'
    }
  }
]

output functionAppName string = functionAppDeployment.outputs.name
output functionAppResourceGroupName string = functionAppDeployment.outputs.resourceGroupName
