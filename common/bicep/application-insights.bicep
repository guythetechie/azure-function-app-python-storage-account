param name string
param location string
param tags object = {}
param logAnalyticsWorkspaceId string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: 'other'
  properties: {
    Application_Type: 'other'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

output name string = applicationInsights.name
output id string = applicationInsights.id
output connectionString string = applicationInsights.properties.ConnectionString
