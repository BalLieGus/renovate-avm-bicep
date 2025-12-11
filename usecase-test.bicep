targetScope = 'subscription'

var locationShort = 'we'
var useCaseName = 'test'
var resourceGroupNameServers = 'rg-${locationShort}-${useCaseName}-servers'
var resourceGroupNameBackup = 'rg-${locationShort}-${useCaseName}-backup'
var resourceGroupNameKeyVault = 'rg-${locationShort}-${useCaseName}-keyvault'
module rg_servers 'br/public:avm/res/resources/resource-group:0.4.3' = {
  params: {
    name: resourceGroupNameServers
  }
}

module rg_backup 'br/public:avm/res/resources/resource-group:0.4.3' = {
  params: {
    name: resourceGroupNameBackup
  }
}

module rg_keyVault 'br/public:avm/res/resources/resource-group:0.4.3' = {
  params: {
    name: resourceGroupNameKeyVault
  }
}


module vmpassword 'generate-pass.bicep' = {
  scope: az.resourceGroup(resourceGroupNameKeyVault)
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'vmPassword'
    uamiResourceId: uami.outputs.resourceId
  }
}



module uami 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.3' = {
  scope: az.resourceGroup(resourceGroupNameKeyVault)
  params: {
    name: 'uami-${locationShort}-${useCaseName}-secrets'
  }
}
module keyVault 'br/public:avm/res/key-vault/vault:0.13.3' = {
  scope: az.resourceGroup(resourceGroupNameKeyVault)
  params: {
    name: 'kv-${locationShort}-${useCaseName}-${uniqueString(subscription().id,resourceGroupNameServers,useCaseName)}'
    publicNetworkAccess: 'Enabled'
    enableRbacAuthorization: true
    roleAssignments: [
      {
        principalId: deployer().objectId
        roleDefinitionIdOrName: 'Key Vault Administrator'
      }
      {
        principalId: uami.outputs.principalId
        roleDefinitionIdOrName: 'Key Vault Secrets Officer'
      }
    ]
    enableVaultForTemplateDeployment: true
  }
  dependsOn: [
    rg_servers
  ]
}

resource existingSecrets 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  scope: az.resourceGroup(resourceGroupNameKeyVault)
  name: keyVault.outputs.name
}

module server 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  scope: az.resourceGroup(resourceGroupNameServers)
  params: {
    name: 'vm-${locationShort}-server'
    availabilityZone: -1
    nicConfigurations: [
      {
        name: 'nic-${locationShort}-server-01'
        ipConfigurations: [
          {
            subnetResourceId: '/subscriptions/4ab4f9bc-df83-4539-8e5d-0ffb41b6e6fc/resourceGroups/rg-we-test-network/providers/Microsoft.Network/virtualNetworks/vnet-we-test/subnets/snet-servers'
          }
        ]
      }
    ]
    osDisk: {
      createOption: 'FromImage'
      diskSizeGB: 128
      caching: 'ReadOnly'
      name: 'disk-${locationShort}-server-osdisk'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    imageReference: {
      publisher: 'microsoftwindowsserver'
      offer: 'windowsserver'
      sku: '2022-Datacenter-azure-edition-hotpatch'
      version: 'latest'
    }
    osType: 'Windows'
    vmSize: 'Standard_B2s_v2'
    adminUsername: 'maarten'
    adminPassword: existingSecrets.getSecret(vmpassword.outputs.secretName)
  }
  dependsOn: [
    rg_servers
  ]
}

module backup 'br/public:avm/res/recovery-services/vault:0.11.0' = {
  scope: az.resourceGroup(resourceGroupNameBackup)
  params: {
    name: 'rsv-${locationShort}-${useCaseName}'
    publicNetworkAccess: 'Enabled'
    protectedItems: [
      {
        name: 'vm;iaasvmcontainerv2;${resourceGroupNameServers};${server.outputs.name}'
        policyName: 'DefaultPolicy'
        protectedItemType: 'Microsoft.ClassicCompute/virtualMachines'
        protectionContainerName: 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroupNameServers};${server.outputs.name}'
        sourceResourceId: server.outputs.resourceId
      }
    ]
  }
    dependsOn: [
    rg_backup
  ]
}
