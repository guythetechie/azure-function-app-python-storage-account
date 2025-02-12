param name string
param virtualNetworkName string
param addressPrefix string
param networkSecurityGroupId string?
param routeTableId string?
param delegation string?

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: virtualNetworkName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: name
  parent: virtualNetwork
  properties: {
    addressPrefix: addressPrefix
    networkSecurityGroup: empty(networkSecurityGroupId)
      ? null
      : {
          id: networkSecurityGroupId
        }
    routeTable: empty(routeTableId)
      ? null
      : {
          id: routeTableId
        }
    delegations: empty(delegation)
      ? []
      : [
          {
            name: delegation
            properties: {
              serviceName: delegation
            }
          }
        ]
  }
}

output name string = subnet.name
output id string = subnet.id
output addressPrefix string = subnet.properties.addressPrefix
