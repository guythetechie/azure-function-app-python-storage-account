param name string
param location string
param tags object
param appServicePlanId string
param storageAccountId string
param storageAccountFunctionAppContainerName string
param storageAccountUploadsContainerName string
param storageAccountUploadsQueueName string
param applicationInsightsConnectionString string
param vnetIntegrationSubnetId string

func getResourceName(resourceId string) string => last(split(resourceId, '/'))
func getResourceGroupName(resourceId string) string => split(resourceId, '/')[4]

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: getResourceName(storageAccountId)
  scope: resourceGroup(getResourceGroupName(storageAccountId))
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
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
          value: applicationInsightsConnectionString
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
          name: 'STORAGE_ACCOUNT_UPLOADS_CONTAINER_NAME'
          value: storageAccountUploadsContainerName
        }
        {
          name: 'STORAGE_ACCOUNT_UPLOADS_QUEUE_NAME'
          value: storageAccountUploadsQueueName
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
    virtualNetworkSubnetId: vnetIntegrationSubnetId
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: uri(storageAccount.properties.primaryEndpoints.blob, storageAccountFunctionAppContainerName)
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

output name string = functionApp.name
output id string = functionApp.id
output principalId string = functionApp.identity.principalId
