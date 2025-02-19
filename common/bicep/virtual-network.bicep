param name string
param location string
param tags object
param addressPrefixes string[]
param hubVirtualNetworkId string?

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    virtualNetworkPeerings: [
      {
        name: 'peer'
        properties: {
          allowVirtualNetworkAccess: true
          allowForwardedTraffic: false
          allowGatewayTransit: true
          useRemoteGateways: true
          remoteVirtualNetwork: {
            id: hubVirtualNetworkId
          }
        }
      }
    ]
  }
}

output name string = virtualNetwork.name
output id string = virtualNetwork.id
