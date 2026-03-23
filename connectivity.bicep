targetScope = 'subscription'

var locationShort = 'we'
var useCaseName = 'hub'
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

module vnet 'br/public:avm/res/network/virtual-network:0.7.2' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'vnet-${locationShort}-${useCaseName}'
    addressPrefixes: [
      '10.1.1.0/24'
    ]
    subnets: [
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.1.1.0/26'
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.1.1.64/26'
      }
    ]
    peerings: [
      {
        remoteVirtualNetworkResourceId: '/subscriptions/4ab4f9bc-df83-4539-8e5d-0ffb41b6e6fc/resourceGroups/rg-we-test-network/providers/Microsoft.Network/virtualNetworks/vnet-we-test'
        remotePeeringEnabled: true
      }
    ]
  }
  dependsOn: [
    networkWatcher
  ]
}

module vng 'br/public:avm/res/network/virtual-network-gateway:0.10.1' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'vng-${locationShort}-${useCaseName}-vpn'
    clusterSettings: {
      clusterMode: 'activePassiveNoBgp'
    }
    gatewayType: 'Vpn'
    skuName: 'VpnGw1AZ'
    virtualNetworkResourceId: vnet.outputs.resourceId
  }
}

module lng 'br/public:avm/res/network/local-network-gateway:0.4.0' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'lng-${locationShort}-kortemark'
    localGatewayPublicIpAddress: '1.2.3.4'
    localNetworkAddressSpace: {
      addressPrefixes: [
        '192.168.1.0/24'
      ]
    }
  }
}

module connection_kortemark 'br/public:avm/res/network/connection:0.1.6' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'conn-${locationShort}-kortemark'
    virtualNetworkGateway1: {
      id: vng.outputs.resourceId
    }
    localNetworkGateway2ResourceId: lng.outputs.resourceId
    // vpnSharedKey: 
  }
}

module firewall 'br/public:avm/res/network/azure-firewall:0.9.2' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'afw-${locationShort}-${useCaseName}'
    availabilityZones: [1, 2, 3]
    azureSkuTier: 'Standard'
    firewallPolicyId: firewall_policy.outputs.resourceId
    virtualNetworkResourceId: vnet.outputs.resourceId
    enableManagementNic: false
  }
}

module firewall_policy 'br/public:avm/res/network/firewall-policy:0.3.4' = {
  scope: az.resourceGroup(resourceGroupNameNetwork)
  params: {
    name: 'afwp-${locationShort}-${useCaseName}'
    enableProxy: true
    ruleCollectionGroups: [
      {
        name: 'rule-001'
        priority: 5000
        ruleCollections: [
          {
            action: {
              type: 'Allow'
            }
            name: 'collection002'
            priority: 5555
            ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
            rules: [
              {
                destinationAddresses: [
                  '*'
                ]
                destinationFqdns: []
                destinationIpGroups: []
                destinationPorts: [
                  '80'
                ]
                ipProtocols: [
                  'TCP'
                  'UDP'
                ]
                name: 'rule002'
                ruleType: 'NetworkRule'
                sourceAddresses: [
                  '*'
                ]
                sourceIpGroups: []
              }
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [
    rg_network
  ]
}
