@description('Required. The base for resource names')
param baseName string

@description('Optional. The location to deploy. Defaults to resourceGroup().location')
param location string = resourceGroup().location

@description('Optional. Tags for this resource. Defaults to resourceGroup().tags')
param tags object = resourceGroup().tags

@description ('''Optional. A dictionary of subject identifiers to issuer URLs for configuring federated identity. Defaults to empty.
Supports creating Azure Workload Identity federation credentials. For example:
{
  // Format: subject identifier: issuerUrl

  // supports creating github actions wofklow connections:
  'repo:PoshCode/cluster:ref:refs/heads/main': 'https://token.actions.githubusercontent.com'

  // suppports creating AKS Workload Identities:
  'system:serviceaccount:${AKSNamespaceName}:${AKSServiceAccountName}': cluster.oidcIssuerURL

  // If necessary, add a trailing moreunique value that will be stripped out and ignored (I needed this for specific issues with clusters sharing identities)
  'system:serviceaccount:${AKSNamespaceName}:${AKSServiceAccountName}:moreunique:${cluster.oidcIssuerURL}': cluster.oidcIssuerURL
}''')
param federatedIdentitySubjectIssuerDictionary object = {}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${baseName}'
  location: location
  tags: tags
}

resource credential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2022-01-31-preview' = [for issuer in items(federatedIdentitySubjectIssuerDictionary): {
  name: replace(replace(replace(issuer.key,'system:serviceaccount:',''),':','-'),'/','-')
  parent: userAssignedIdentity
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: issuer.value
    // if the issuer URL is in the name, it's there as a differentiator, take it out
    subject: split(issuer.key,':moreunique:')[0]
  }
}]


@description('Resource ID, for deployment scripts')
output id string = userAssignedIdentity.id

@description('Principal ID, for Azure Role assignement')
output principalId string = userAssignedIdentity.properties.principalId

@description('Client ID, for application config (so we can use this identity from code)')
output clientId string = userAssignedIdentity.properties.clientId
