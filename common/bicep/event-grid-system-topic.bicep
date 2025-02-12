param name string
param location string
param tags object
param logAnalyticsWorkspaceId string
param sourceResourceId string
param topicType string

resource topic 'Microsoft.EventGrid/systemTopics@2024-12-15-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    source: sourceResourceId
    topicType: topicType
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'enable-all'
  scope: topic
  properties: {
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    logAnalyticsDestinationType: 'Dedicated'
    workspaceId: logAnalyticsWorkspaceId
  }
}

output name string = topic.name
output id string = topic.id
output principalId string = topic.identity.principalId
