@description('Required. The base for resource names')
param baseName string

@description('Optional. The location to deploy. Defaults to resourceGroup().location')
param location string = resourceGroup().location

@description('Optional. Tags for this resource. Defaults to resourceGroup().tags')
param tags object = resourceGroup().tags

@description ('''Optional. A dictionary of issuer URL to subjects for configuring federated identity. Defaults to empty.
Supports creating Azure Workload Identity federation credentials. For example:
{
  issuerUrl: the federated identity
  cluster.oidcIssuerURL: 'system:serviceaccount:${AKSNamespaceName}:${AKSServiceAccountName}'
}''')
param azureADTokenExchangeFederatedIdentityCredentials object = {}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${baseName}'
  location: location
  tags: tags
}

resource credential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2022-01-31-preview' = [for issuer in items(azureADTokenExchangeFederatedIdentityCredentials): {
  name: replace(replace(issuer.value, 'system:serviceaccount:',''),':','-')
  parent: userAssignedIdentity
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: issuer.key
    subject: issuer.value
  }
}]


@description('Resource ID, for deployment scripts')
output id string = userAssignedIdentity.id

@description('Principal ID, for Azure Role assignement')
output principalId string = userAssignedIdentity.properties.principalId

@description('Client ID, for application config (so we can use this identity from code)')
output clientId string = userAssignedIdentity.properties.clientId
