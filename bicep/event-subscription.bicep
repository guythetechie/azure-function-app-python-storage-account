param storageAccountName string
param storageAccountQueueName string
param eventGridTopicName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource storageAccountQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' = {
  name: storageAccountQueueName
  parent: queueServices
}

resource eventGridTopic 'Microsoft.EventGrid/systemTopics@2024-06-01-preview' existing = {
  name: eventGridTopicName
}

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = {
  name: '${storageAccount.name}-${storageAccountQueue.name}'
  parent: eventGridTopic
  properties: {
    destination: {
      properties: {
        queueName: storageAccountQueue.name
        resourceId: storageAccount.id
      }
      endpointType: 'StorageQueue'
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
      ]
    }
  }
}
