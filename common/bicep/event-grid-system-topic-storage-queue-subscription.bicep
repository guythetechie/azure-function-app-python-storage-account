param name string
param topicName string
param queueId string
param filter resourceInput<'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-12-15-preview'>.properties.filter?

resource eventGridTopic 'Microsoft.EventGrid/systemTopics@2024-12-15-preview' existing = {
  name: topicName
}

resource eventSubscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-12-15-preview' = {
  name: name
  parent: eventGridTopic
  properties: {
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    deliveryWithResourceIdentity: {
      destination: {
        properties: {
          queueName: last(split(queueId, '/'))
          #disable-next-line use-resource-id-functions
          resourceId: join(take(split(queueId, '/'), 9), '/')
        }
        endpointType: 'StorageQueue'
      }
      identity: {
        type: 'SystemAssigned'
      }
    }
    filter: filter
  }
}
