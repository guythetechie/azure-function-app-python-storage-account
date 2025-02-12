type PrivateDnsZone = {
  name: string
  id: string
}
param location string
param tags object
param resourceId string
param group string
param subnetId string
param privateDnsZones PrivateDnsZone[]

var resourceName = last(split(resourceId, '/'))

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${resourceName}-${group}-private-endpoint'
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: '${resourceName}-${group}-nic'
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'azuremonitor'
        properties: {
          privateLinkServiceId: resourceId
          groupIds: [
            group
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (!empty(privateDnsZones)) {
  name: 'private-dns-zone-group'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      for zone in privateDnsZones: {
        name: zone.name
        properties: {
          #disable-next-line use-resource-id-functions
          privateDnsZoneId: zone.id
        }
      }
    ]
  }
}
