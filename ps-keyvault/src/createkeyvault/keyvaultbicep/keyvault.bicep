// ================ //
// Parameters       //
// ================ //
@description('Required. Name of the Key Vault. Must be globally unique.')
@maxLength(24)
param name string

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Optional. All access policies to create.')
param accessPolicies array = []

@description('Optional. All secrets to create.')
@secure()
param secrets object = {}

@description('Optional. All keys to create.')
param keys array = []

@description('Optional. Specifies if the vault is enabled for deployment by script or compute.')
param enableVaultForDeployment bool = true

@description('Optional. Specifies if the vault is enabled for a template deployment.')
param enableVaultForTemplateDeployment bool = true

@description('Optional. Specifies if the azure platform has access to the vault for enabling disk encryption scenarios.')
param enableVaultForDiskEncryption bool = true

@description('Optional. Switch to enable/disable Key Vault\'s soft delete feature.')
param enableSoftDelete bool = true

@description('Optional. softDelete data retention days. It accepts >=7 and <=90.')
param softDeleteRetentionInDays int = 90

@description('Optional. Property that controls how data actions are authorized. When true, the key vault will use Role Based Access Control (RBAC) for authorization of data actions, and the access policies specified in vault properties will be ignored. When false, the key vault will use the access policies specified in vault properties, and any policy stored on Azure Resource Manager will be ignored. Note that management actions are always authorized with RBAC.')
param enableRbacAuthorization bool = true

@description('Optional. The vault\'s create mode to indicate whether the vault need to be recovered or not. - recover or default.')
param createMode string = 'default'

@description('Optional. Provide \'true\' to enable Key Vault\'s purge protection feature.')
param enablePurgeProtection bool = true

@description('Optional. Specifies the SKU for the vault.')
@allowed([
  'premium'
  'standard'
])
param vaultSku string = 'standard'

@description('Optional. Service endpoint object information. For security reasons, it is recommended to set the DefaultAction Deny.')
param networkAcls object = {}

@description('Optional. Whether or not public network access is allowed for this resource. For security reasons it should be disabled. If not specified, it will be disabled by default if private endpoints are set and networkAcls are not set.')
@allowed([
  ''
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Optional. Resource tags.')
param tags object?

var formattedAccessPolicies = [
  for accessPolicy in accessPolicies: {
    applicationId: contains(accessPolicy, 'applicationId') ? accessPolicy.applicationId : ''
    objectId: contains(accessPolicy, 'objectId') ? accessPolicy.objectId : ''
    permissions: accessPolicy.permissions
    tenantId: contains(accessPolicy, 'tenantId') ? accessPolicy.tenantId : tenant().tenantId
  }
]

var secretList = !empty(secrets) ? secrets.secureList : []

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    enabledForDeployment: enableVaultForDeployment
    enabledForTemplateDeployment: enableVaultForTemplateDeployment
    enabledForDiskEncryption: enableVaultForDiskEncryption
    enableSoftDelete: enableSoftDelete
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enableRbacAuthorization: enableRbacAuthorization
    createMode: createMode
    enablePurgeProtection: enablePurgeProtection ? enablePurgeProtection : null
    tenantId: subscription().tenantId
    accessPolicies: formattedAccessPolicies
    sku: {
      name: vaultSku
      family: 'A'
    }
    networkAcls: !empty(networkAcls)
      ? {
          bypass: contains(networkAcls, 'bypass') ? networkAcls.bypass : null
          defaultAction: contains(networkAcls, 'defaultAction') ? networkAcls.defaultAction : null
          virtualNetworkRules: contains(networkAcls, 'virtualNetworkRules') ? networkAcls.virtualNetworkRules : []
          ipRules: contains(networkAcls, 'ipRules') ? networkAcls.ipRules : []
        }
      : null
    publicNetworkAccess: publicNetworkAccess
  }
}

module keyVault_accessPolicies './access_policies/access_policies.bicep' = if (!empty(accessPolicies)) {
  name: '${uniqueString(deployment().name, location)}-KeyVault-AccessPolicies'
  params: {
    keyVaultName: keyVault.name
    accessPolicies: formattedAccessPolicies
  }
}

module keyVault_secrets './secret/secret.bicep' = [
  for (secret, index) in secretList: {
    name: '${uniqueString(deployment().name, location)}-KeyVault-Secret-${index}'
    params: {
      name: secret.name
      value: secret.value
      keyVaultName: keyVault.name
      attributesEnabled: contains(secret, 'attributesEnabled') ? secret.attributesEnabled : true
      attributesExp: contains(secret, 'attributesExp') ? secret.attributesExp : -1
      attributesNbf: contains(secret, 'attributesNbf') ? secret.attributesNbf : -1
      contentType: contains(secret, 'contentType') ? secret.contentType : ''
      tags: secret.?tags ?? tags
    }
  }
]

module keyVault_keys './key/key.bicep' = [
  for (key, index) in keys: {
    name: '${uniqueString(deployment().name, location)}-KeyVault-Key-${index}'
    params: {
      name: key.name
      keyVaultName: keyVault.name
      attributesEnabled: contains(key, 'attributesEnabled') ? key.attributesEnabled : true
      attributesExp: contains(key, 'attributesExp') ? key.attributesExp : -1
      attributesNbf: contains(key, 'attributesNbf') ? key.attributesNbf : -1
      curveName: contains(key, 'curveName') ? key.curveName : 'P-256'
      keyOps: contains(key, 'keyOps') ? key.keyOps : []
      keySize: contains(key, 'keySize') ? key.keySize : -1
      kty: contains(key, 'kty') ? key.kty : 'EC'
      tags: key.?tags ?? tags
      rotationPolicy: contains(key, 'rotationPolicy') ? key.rotationPolicy : {}
    }
  }
]

// =========== //
// Outputs     //
// =========== //

@description('The resource ID of the key vault.')
output resourceId string = keyVault.id

@description('The name of the resource group the key vault was created in.')
output resourceGroupName string = resourceGroup().name

@description('The name of the key vault.')
output name string = keyVault.name

@description('The URI of the key vault.')
output uri string = keyVault.properties.vaultUri

@description('The location the resource was deployed into.')
output location string = keyVault.location
