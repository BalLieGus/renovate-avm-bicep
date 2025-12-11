targetScope = 'subscription'

var locationShort = 'we'
var useCaseName = 'test'
var resourceGroupNameNetwork = 'rg-${locationShort}-${useCaseName}-network'

module rg_network 'br/public:avm/res/resources/resource-group:0.4.3' = {
  params: {
    name: resourceGroupNameNetwork
  }
}

module networkWatcher 'br/public:avm/res/network/network-watcher:0.5.0' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  name: 'nw-${locationShort}-${useCaseName}'
  dependsOn: [
    rg_network
  ]
}

module defaultRoute 'br/public:avm/res/network/route-table:0.5.0' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'rt-vnet-${locationShort}-${useCaseName}'
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: '192.168.1.69'
        }
      }
    ]
  }
  dependsOn: [
    rg_network
  ]
}

module nsgServers 'br/public:avm/res/network/network-security-group:0.5.2' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'nsg-vnet-${locationShort}-${useCaseName}-snet-servers'
  }
  dependsOn: [
    rg_network
  ]
}

module vnet 'br/public:avm/res/network/virtual-network:0.7.2' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'vnet-${locationShort}-${useCaseName}'
    addressPrefixes: [
      '10.1.2.0/24'
    ]
    subnets: [
      {
        name: 'snet-servers'
        addressPrefix: '10.1.2.0/26'
        routeTableResourceId: defaultRoute.outputs.resourceId
        networkSecurityGroupResourceId: nsgServers.outputs.resourceId
      }
    ]
  }
  dependsOn: [
    networkWatcher
  ]
}
