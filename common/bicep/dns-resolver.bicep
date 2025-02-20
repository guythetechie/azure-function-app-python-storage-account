param name string
param location string
param tags object
param virtualNetworkId string
param outboundEndpointSubnetId string

resource dnsResolver 'Microsoft.Network/dnsResolvers@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

resource dnsResolverOutboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  name: 'default'
  parent: dnsResolver
  location: location
  properties: {
    subnet: {
      id: outboundEndpointSubnetId
    }
  }
}

output name string = dnsResolver.name
output id string = dnsResolver.id
output outboundEndpointName string = dnsResolverOutboundEndpoint.name
output outboundEndpointId string = dnsResolverOutboundEndpoint.id
