param name string?
param queueName string
param storageAccountName string
@allowed([
  'Storage Queue Data Reader'
  'Storage Queue Data Message Sender'
])
param roleName string
param principalId string
param principalType null | 'ServicePrincipal' | 'User' | 'Group' | 'ForeignGroup' | 'Device'

var roleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  {
    'Storage Queue Data Reader': '19e7f393-937e-4f77-808e-94535e297925'
    'Storage Queue Data Message Sender': 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
  }[roleName]
)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' existing = {
  name: 'default'
  parent: storageAccount
}

resource queue 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' existing = {
  name: queueName
  parent: queueServices
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: name ?? guid(principalId, queue.id, roleDefinitionId)
  scope: queue
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: principalType
  }
}
