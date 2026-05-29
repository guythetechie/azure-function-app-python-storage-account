targetScope = 'subscription'

import { getPrefix, getShortAlphaNumericPrefix } from '../common/bicep/functions.bicep'

param allowedIpAddressesCsv string = ''
param deploymentStackName string
param entraAdminObjectIds string = ''
param location string
param tags object = {}

var prefix = getPrefix(deploymentStackName)

var allowedPublicIpAddressList = empty(allowedIpAddressesCsv)
  ? []
  : map(split(allowedIpAddressesCsv, ','), address => trim(address))

var entraAdminObjectIdList = filter(
  map(split(entraAdminObjectIds, ','), objectId => trim(objectId)),
  objectId => !empty(objectId)
)

var roleDefinitions = {
  MonitoringMetricsPublisher: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '3913510d-42f4-4e42-8a64-420c390055eb'
  )
  StorageBlobDataContributor: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  )
  StorageBlobDataOwner: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  )
  StorageQueueDataContributor: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  )
  StorageTableDataContributor: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  )
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: '${prefix}-rg'
  location: location
  tags: tags
}

// MONITORING
var applicationInsightsName = '${prefix}-insights'
var logAnalyticsWorkspaceName = '${prefix}-law'

module logAnalyticsWorkspaceDeployment 'br/public:avm/res/operational-insights/workspace:0.15.1' = {
  scope: resourceGroup
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    skuName: 'PerGB2018'
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' existing = {
  name: logAnalyticsWorkspaceName
  dependsOn: [logAnalyticsWorkspaceDeployment]
  scope: resourceGroup
}

module applicationInsightsDeployment 'br/public:avm/res/insights/component:0.7.1' = {
  scope: resourceGroup
  params: {
    name: applicationInsightsName
    location: location
    workspaceResourceId: logAnalyticsWorkspace.id
    disableLocalAuth: true
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
  scope: resourceGroup
  dependsOn: [applicationInsightsDeployment]
}

module privateLinkScopeDeployment 'br/public:avm/res/insights/private-link-scope:0.7.2' = {
  scope: resourceGroup
  params: {
    name: 'ampls'
    location: 'global'
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'Open'
    }
    privateEndpoints: [
      {
        name: 'ampls-azuremonitor-private-endpoint'
        location: location
        customNetworkInterfaceName: 'ampls-azuremonitor-nic'
        service: 'azuremonitor'
        privateLinkServiceConnectionName: 'azuremonitor'
        subnetResourceId: privateLinkSubnet.id
        privateDnsZoneGroup: {
          name: 'default'
          privateDnsZoneGroupConfigs: [
            for item in amplsPrivateDnsZones: {
              name: item.zone.value.name
              privateDnsZoneResourceId: privateDnsZoneDeployments[item.index].outputs.resourceId
            }
          ]
        }
      }
    ]
    scopedResources: [
      {
        name: logAnalyticsWorkspace.name
        linkedResourceId: logAnalyticsWorkspace.id
      }
      {
        name: applicationInsights.name
        linkedResourceId: applicationInsights.id
      }
    ]
  }
}

resource privateLinkScope 'Microsoft.Insights/privateLinkScopes@2023-06-01-preview' existing = {
  name: privateLinkScopeDeployment.outputs.name
  scope: resourceGroup
}

// IDENTITY

var managedIdentityName = '${prefix}-uami'

module managedIdentityDeployment 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.1' = {
  scope: resourceGroup
  params: {
    name: managedIdentityName
    location: location
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  scope: resourceGroup
  name: managedIdentityName
  dependsOn: [managedIdentityDeployment]
}

module managedIdentityMonitoringMetricsPublisherRoleAssignmentDeployment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  params: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    resourceId: applicationInsights.id
    roleDefinitionId: roleDefinitions.MonitoringMetricsPublisher
  }
}

module managedIdentityStorageBlobDataContributorRoleAssignmentDeployment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  params: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.StorageBlobDataContributor
  }
}

module managedIdentityStorageBlobDataOwnerRoleAssignmentDeployment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  params: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.StorageBlobDataOwner
  }
}

module managedIdentityStorageQueueDataContributorRoleAssignmentDeployment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  params: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.StorageQueueDataContributor
  }
}

module managedIdentityStorageTableDataContributorRoleAssignmentDeployment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.1' = {
  scope: resourceGroup
  params: {
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    resourceId: storageAccount.id
    roleDefinitionId: roleDefinitions.StorageTableDataContributor
  }
}

// CONNECTIVITY

var networkSecurityGroupName = '${prefix}-nsg'
var virtualNetworkName = '${prefix}-vnet'
var virtualNetworkAddressPrefix = '10.0.0.0/24'

var subnets = {
  privateLink: {
    name: 'private-link'
    addressPrefix: cidrSubnet(virtualNetworkAddressPrefix, 26, 0)
  }
  azureFunctions: {
    name: 'azure-functions'
    addressPrefix: cidrSubnet(virtualNetworkAddressPrefix, 27, 2)
    delegation: 'Microsoft.App/environments'
  }
}

var privateDnsZones = {
  monitor: {
    name: 'privatelink.monitor.azure.com'
  }
  oms: {
    name: 'privatelink.oms.opinsights.azure.com'
  }
  ods: {
    name: 'privatelink.ods.opinsights.azure.com'
  }
  agentService: {
    name: 'privatelink.agentsvc.azure-automation.net'
  }
  blob: {
    name: 'privatelink.blob.${environment().suffixes.storage}'
  }
  queue: {
    name: 'privatelink.queue.${environment().suffixes.storage}'
  }
  table: {
    name: 'privatelink.table.${environment().suffixes.storage}'
  }
}

var amplsPrivateDnsZones = filter(
  map(items(privateDnsZones), (zone, index) => {
    index: index
    zone: zone
  }),
  item =>
    contains(
      [
        privateDnsZones.monitor.name
        privateDnsZones.oms.name
        privateDnsZones.ods.name
        privateDnsZones.agentService.name
        privateDnsZones.blob.name
      ],
      item.zone.value.name
    )
)
module networkSecurityGroupDeployment 'br/public:avm/res/network/network-security-group:0.5.3' = {
  scope: resourceGroup
  params: {
    name: networkSecurityGroupName
    location: location
    securityRules: []
    diagnosticSettings: [
      {
        name: 'enable-all'
        logAnalyticsDestinationType: 'Dedicated'
        workspaceResourceId: logAnalyticsWorkspace.id
        logCategoriesAndGroups: [
          {
            categoryGroup: 'allLogs'
            enabled: true
          }
        ]
      }
    ]
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2025-05-01' existing = {
  name: networkSecurityGroupName
  scope: resourceGroup
  dependsOn: [networkSecurityGroupDeployment]
}

module virtualNetworkDeployment 'br/public:avm/res/network/virtual-network:0.9.0' = {
  scope: resourceGroup
  params: {
    name: virtualNetworkName
    location: location
    addressPrefixes: [virtualNetworkAddressPrefix]
    subnets: [
      for subnet in items(subnets): {
        name: subnet.value.name
        addressPrefix: subnet.value.addressPrefix
        delegation: subnet.value.?delegation
        networkSecurityGroupResourceId: networkSecurityGroup.id
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup
  dependsOn: [virtualNetworkDeployment]
}

resource privateLinkSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' existing = {
  parent: virtualNetwork
  name: subnets.privateLink.name
}

resource azureFunctionsSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-10-01' existing = {
  parent: virtualNetwork
  name: subnets.azureFunctions.name
}

module privateDnsZoneDeployments 'br/public:avm/res/network/private-dns-zone:0.8.1' = [
  for zone in items(privateDnsZones): {
    scope: resourceGroup
    params: {
      name: zone.value.name
      location: 'global'
    }
  }
]

resource storageBlobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZones.blob.name
  scope: resourceGroup
  dependsOn: [privateDnsZoneDeployments]
}

resource storageQueuePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZones.queue.name
  scope: resourceGroup
  dependsOn: [privateDnsZoneDeployments]
}

resource storageTablePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZones.table.name
  scope: resourceGroup
  dependsOn: [privateDnsZoneDeployments]
}

resource odsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZones.ods.name
  scope: resourceGroup
  dependsOn: [privateDnsZoneDeployments]
}

resource monitorPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZones.monitor.name
  scope: resourceGroup
  dependsOn: [privateDnsZoneDeployments]
}

resource omsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZones.oms.name
  scope: resourceGroup
  dependsOn: [privateDnsZoneDeployments]
}

resource agentServicePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZones.agentService.name
  scope: resourceGroup
  dependsOn: [privateDnsZoneDeployments]
}

module amplsPrivateDnsZoneLinks 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = [
  for zone in [
    {
      name: monitorPrivateDnsZone.name
      resourceId: monitorPrivateDnsZone.id
    }
    {
      name: omsPrivateDnsZone.name
      resourceId: omsPrivateDnsZone.id
    }
    {
      name: odsPrivateDnsZone.name
      resourceId: odsPrivateDnsZone.id
    }
    {
      name: agentServicePrivateDnsZone.name
      resourceId: agentServicePrivateDnsZone.id
    }
  ]: {
    scope: resourceGroup
    params: {
      privateDnsZoneName: zone.name
      virtualNetworkResourceId: virtualNetwork.id
      name: virtualNetwork.name
    }
  }
]

module storageBlobPrivateDnsZoneLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup
  params: {
    privateDnsZoneName: storageBlobPrivateDnsZone.name
    virtualNetworkResourceId: virtualNetwork.id
    name: virtualNetwork.name
  }
}

module storageQueuePrivateDnsZoneLink 'br/public:avm/res/network/private-dns-zone/virtual-network-link:0.1.0' = {
  scope: resourceGroup
  params: {
    privateDnsZoneName: storageQueuePrivateDnsZone.name
    virtualNetworkResourceId: virtualNetwork.id
    name: virtualNetwork.name
  }
}

// STORAGE

var storageAccountName = '${getShortAlphaNumericPrefix(deploymentStackName, 22)}st'
var storageAccountFunctionAppContainerName = 'function-app'

module storageDeployment 'br/public:avm/res/storage/storage-account:0.14.0' = {
  scope: resourceGroup
  dependsOn: [
    amplsPrivateDnsZoneLinks
    storageBlobPrivateDnsZoneLink
    storageQueuePrivateDnsZoneLink
  ]
  params: {
    name: storageAccountName
    location: location
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: empty(allowedPublicIpAddressList) ? 'Disabled' : 'Enabled'
    requireInfrastructureEncryption: false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
      ipRules: [
        for ipAddress in allowedPublicIpAddressList: {
          action: 'Allow'
          value: ipAddress
        }
      ]
      virtualNetworkRules: []
    }
    roleAssignments: [
      for objectId in entraAdminObjectIdList: {
        principalId: objectId
        roleDefinitionIdOrName: roleDefinitions.StorageBlobDataContributor
      }
    ]
    blobServices: {
      containers: [
        {
          name: storageAccountFunctionAppContainerName
          publicAccess: 'None'
        }
      ]
      diagnosticSettings: [
        {
          name: 'enable-all'
          logAnalyticsDestinationType: 'Dedicated'
          workspaceResourceId: logAnalyticsWorkspace.id
          logCategoriesAndGroups: [
            {
              categoryGroup: 'allLogs'
              enabled: true
            }
          ]
          metricCategories: []
        }
      ]
    }
    queueServices: {
      diagnosticSettings: [
        {
          name: 'enable-all'
          logAnalyticsDestinationType: 'Dedicated'
          workspaceResourceId: logAnalyticsWorkspace.id
          logCategoriesAndGroups: [
            {
              categoryGroup: 'allLogs'
              enabled: true
            }
          ]
          metricCategories: []
        }
      ]
    }
    tableServices: {
      diagnosticSettings: [
        {
          name: 'enable-all'
          logAnalyticsDestinationType: 'Dedicated'
          workspaceResourceId: logAnalyticsWorkspace.id
          logCategoriesAndGroups: [
            {
              categoryGroup: 'allLogs'
              enabled: true
            }
          ]
          metricCategories: []
        }
      ]
    }
    privateEndpoints: [
      {
        name: '${storageAccountName}-blob-pe'
        location: location
        customNetworkInterfaceName: '${storageAccountName}-blob-pe-nic'
        service: 'blob'
        privateLinkServiceConnectionName: 'blob'
        subnetResourceId: privateLinkSubnet.id
        privateDnsZoneGroup: {
          name: 'default'
          privateDnsZoneGroupConfigs: [
            {
              name: 'blob'
              privateDnsZoneResourceId: storageBlobPrivateDnsZone.id
            }
          ]
        }
      }
      {
        name: '${storageAccountName}-queue-pe'
        location: location
        customNetworkInterfaceName: '${storageAccountName}-queue-pe-nic'
        service: 'queue'
        privateLinkServiceConnectionName: 'queue'
        subnetResourceId: privateLinkSubnet.id
        privateDnsZoneGroup: {
          name: 'default'
          privateDnsZoneGroupConfigs: [
            {
              name: 'queue'
              privateDnsZoneResourceId: storageQueuePrivateDnsZone.id
            }
          ]
        }
      }
      {
        name: '${storageAccountName}-table-pe'
        location: location
        customNetworkInterfaceName: '${storageAccountName}-table-pe-nic'
        service: 'table'
        privateLinkServiceConnectionName: 'table'
        subnetResourceId: privateLinkSubnet.id
        privateDnsZoneGroup: {
          name: 'default'
          privateDnsZoneGroupConfigs: [
            {
              name: 'table'
              privateDnsZoneResourceId: storageTablePrivateDnsZone.id
            }
          ]
        }
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: storageAccountName
  scope: resourceGroup
  dependsOn: [storageDeployment]
}

resource storageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource storageAccountFunctionAppContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' existing = {
  name: storageAccountFunctionAppContainerName
  parent: storageBlobService
}

// FUNCTION APP

var appServicePlanName = '${prefix}-asp'
var functionAppName = '${prefix}-function-app'

module appServicePlanDeployment 'br/public:avm/res/web/serverfarm:0.7.0' = {
  scope: resourceGroup
  params: {
    name: appServicePlanName
    location: location
    skuName: 'FC1'
    workerTierName: 'FlexConsumption'
    reserved: true
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2025-03-01' existing = {
  name: appServicePlanName
  dependsOn: [appServicePlanDeployment]
  scope: resourceGroup
}

module functionAppDeployment 'br/public:avm/res/web/site:0.23.0' = {
  scope: resourceGroup
  params: {
    name: functionAppName
    location: location
    kind: 'functionapp,linux'
    serverFarmResourceId: appServicePlan.id
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.id]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${storageAccountFunctionAppContainer.name}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: managedIdentity.id
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
    configs: [
      {
        name: 'appsettings'
        properties: {
          AzureWebJobsStorage__accountName: storageAccount.name
          AzureWebJobsStorage__credential: 'managedidentity'
          AzureWebJobsStorage__clientId: managedIdentity.properties.clientId
          APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${managedIdentity.properties.clientId};Authorization=AAD'
          APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
        }
      }
      {
        name: 'web'
        properties: {
          cors: {
            allowedOrigins: [
              'https://portal.azure.com'
            ]
          }
        }
      }
    ]
    outboundVnetRouting: {
      allTraffic: false
      contentShareTraffic: true
      imagePullTraffic: true
    }
    virtualNetworkSubnetResourceId: azureFunctionsSubnet.id
  }
}

resource functionApp 'Microsoft.Web/sites@2025-03-01' existing = {
  name: functionAppName
  dependsOn: [functionAppDeployment]
  scope: resourceGroup
}

output resourceGroupName string = resourceGroup.name
output functionAppName string = functionApp.name
