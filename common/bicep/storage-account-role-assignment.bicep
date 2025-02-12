param name string?
param storageAccountName string
@allowed([
  'Storage Blob Data Owner'
  'Storage Queue Data Message Sender'
])
param roleName string
param principalId string
param principalType null | 'ServicePrincipal' | 'User' | 'Group' | 'ForeignGroup' | 'Device'

var roleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  {
    'Storage Blob Data Owner': 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
    'Storage Queue Data Message Sender': 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
  }[roleName]
)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: name ?? guid(principalId, storageAccount.id, roleDefinitionId)
  scope: storageAccount
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: principalType
  }
}
