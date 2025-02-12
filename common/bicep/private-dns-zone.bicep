param name string
param tags object
param virtualNetworkId string?

resource zone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: name
  location: 'global'
  tags: tags
  properties: {}
}

resource zoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  name: last(split(virtualNetworkId ?? '', '/'))
  parent: zone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: empty(virtualNetworkId)
      ? null
      : {
          id: virtualNetworkId
        }
  }
}

output name string = zone.name
output id string = zone.id
