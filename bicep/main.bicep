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
param functionAppName string = '${prefix}-funcapp'
param serviceBusNamespaceName string = '${prefix}-service-bus'
param allowedIpAddressesSring string = ''
param eventGridTopicName string = '${storageAccountName}-system-topic'
param eventGridSubscriptionName string = 'on-blob-change'

var functionAppDeploymentContainerName = '${functionAppName}-deployment'
var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
var allowedIpAddresses = map(split(allowedIpAddressesSring, ','), address => trim(address))
var serviceBusEventGridSubscriptionTopicName = eventGridSubscriptionName
var serviceBusEventGridSubscriptionTopicFunctionAppSubscriptionName = functionAppName

resource storageAccountDataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
}

resource serviceBusDataReceiverRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  scope: subscription()
}

resource serviceBusDataSenderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
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
        virtualNetworkResourceId: virtualNetworkDeployment.outputs.resourceId
      }
    ]
  }
}

module serviceBusPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.6.0' = {
  scope: resourceGroup
  name: 'service-bus-private-dns-zone-deployment'
  dependsOn: [resourceGroupDeployment]
  params: {
    name: 'privatelink.servicebus.windows.net'
    location: 'global'
    tags: tags
    virtualNetworkLinks: [
      {
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
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
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
          name: functionAppDeploymentContainerName
          publicAccess: 'None'
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

resource storageAccountFunctionAppDeploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  name: functionAppDeploymentContainerName
  parent: storageAccountBlobService
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
    serverFarmResourceId: appServicePlanDeployment.outputs.resourceId
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: storageAccountConnectionString
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'DEPLOYMENT_STORAGE_ACCOUNT_CONNECTION_STRING'
          value: storageAccountConnectionString
        }
        {
          name: 'STORAGE_ACCOUNT_CONTAINER_NAME'
          value: functionAppDeploymentContainerName
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
          value: uri(storageAccountDeployment.outputs.primaryBlobEndpoint, functionAppDeploymentContainerName)
          authentication: {
            type: 'StorageAccountConnectionString'
            storageAccountConnectionStringName: 'DEPLOYMENT_STORAGE_ACCOUNT_CONNECTION_STRING'
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

module serviceBusDeployment 'br/public:avm/res/service-bus/namespace:0.10.0' = {
  scope: resourceGroup
  name: 'service-bus-deployment'
  dependsOn: [
    resourceGroupDeployment
    virtualNetworkDeployment
    serviceBusPrivateDnsZone
  ]
  params: {
    name: serviceBusNamespaceName
    location: location
    tags: tags
    disableLocalAuth: true
    networkRuleSets: {
      defaultAction: 'Deny'
      trustedServiceAccessEnabled: true
      publicNetworkAccess: 'Disabled'
      ipRules: empty(allowedIpAddresses)
        ? null
        : map(allowedIpAddresses, address => {
            action: 'Allow'
            ipMask: address
          })
    }
    topics: [
      {
        name: serviceBusEventGridSubscriptionTopicName
        subscriptions: [
          {
            name: serviceBusEventGridSubscriptionTopicFunctionAppSubscriptionName
          }
        ]
      }
    ]
    privateEndpoints: [
      {
        name: '${serviceBusNamespaceName}-pep'
        subnetResourceId: privateEndpointSubnet.id
        customNetworkInterfaceName: '${serviceBusNamespaceName}-nic'
        privateLinkServiceConnectionName: '${serviceBusNamespaceName}-namespace'
        service: 'namespace'
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              name: serviceBusPrivateDnsZone.outputs.name
              privateDnsZoneResourceId: serviceBusPrivateDnsZone.outputs.resourceId
            }
          ]
        }
      }
    ]
  }
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' existing = {
  name: serviceBusNamespaceName
  scope: resourceGroup
}

resource serviceBusEventGridSubscriptionTopic 'Microsoft.ServiceBus/namespaces/topics@2023-01-01-preview' existing = {
  name: serviceBusEventGridSubscriptionTopicName
  parent: serviceBus
}

resource serviceBusEventGridSubscriptionTopicFunctionAppSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2023-01-01-preview' existing = {
  name: serviceBusEventGridSubscriptionTopicFunctionAppSubscriptionName
  parent: serviceBusEventGridSubscriptionTopic
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

module eventGridServiceBusEventGridSubscriptionTopicRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  dependsOn: [
    serviceBusDeployment
  ]
  name: 'event-grid-service-bus-role-assignment'
  params: {
    principalId: eventGridSystemTopicDeployment.outputs.systemAssignedMIPrincipalId
    resourceId: serviceBusEventGridSubscriptionTopic.id
    roleDefinitionId: serviceBusDataSenderRoleDefinition.id
  }
}

module functionAppServiceBusEventGridSubscriptionTopicFunctionAppSubscriptionRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  name: 'function-app-service-bus-role-assignment'
  dependsOn: [
    serviceBusDeployment
  ]
  params: {
    principalId: functionAppDeployment.outputs.systemAssignedMIPrincipalId
    resourceId: serviceBusEventGridSubscriptionTopicFunctionAppSubscription.id
    roleDefinitionId: serviceBusDataReceiverRoleDefinition.id
  }
}

module functionAppStorageAccountFunctionAppDeploymentContainerRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  name: 'function-app-storage-account-role-assignment'
  dependsOn: [
    storageAccountDeployment
  ]
  params: {
    principalId: functionAppDeployment.outputs.systemAssignedMIPrincipalId
    resourceId: storageAccountFunctionAppDeploymentContainer.id
    roleDefinitionId: storageAccountDataReaderRoleDefinition.id
  }
}
