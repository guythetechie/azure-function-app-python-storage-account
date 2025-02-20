import {
  getResourceName
  getResourceGroupName
} from 'functions.bicep'

import { DnsForwardingRule } from 'types.bicep'

param name string
param location string
param tags object
param dnsResolverOutboundEndpointId string
param rules DnsForwardingRule[]
param virtualNetworkIds string[]

resource ruleSet 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    dnsResolverOutboundEndpoints: [
      {
        id: dnsResolverOutboundEndpointId
      }
    ]
  }
}

resource forwardingRules 'Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01' = [
  for rule in rules: {
    name: rule.domainName == '.' ? 'default' : replace(rule.domainName, '.', '_')
    parent: ruleSet
    properties: {
      domainName: endsWith(rule.domainName, '.') ? rule.domainName : '${rule.domainName}.'
      targetDnsServers: [
        for ipAddress in rule.dnsServerIpAddresses: {
          ipAddress: ipAddress
        }
      ]
    }
  }
]

resource virtualNetworks 'Microsoft.Network/virtualNetworks@2024-05-01' existing = [
  for id in virtualNetworkIds: {
    name: getResourceName(id)
    scope: resourceGroup(getResourceGroupName(id))
  }
]

resource virtualNetworkLinks 'Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01' = [
  for (_, index) in virtualNetworkIds: {
    name: virtualNetworks[index].name
    parent: ruleSet
    properties: {
      virtualNetwork: {
        id: virtualNetworks[index].id
      }
    }
  }
]

output name string = ruleSet.name
output id string = ruleSet.id
