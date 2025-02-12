param privateLinkScopeName string
param resourceName string
param resourceId string

resource privateLinkScope 'Microsoft.Insights/privateLinkScopes@2021-07-01-preview' existing = {
  name: privateLinkScopeName
}

resource scopedResource 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  name: resourceName
  parent: privateLinkScope
  properties: {
    linkedResourceId: resourceId
  }
}
