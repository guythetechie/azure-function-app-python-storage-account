param name string
param location string
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 365
  }
}

output name string = logAnalyticsWorkspace.name
output id string = logAnalyticsWorkspace.id
