param name string
param location string
param tags object
param addressPrefixes string[]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
  }
}

output name string = virtualNetwork.name
output id string = virtualNetwork.id
