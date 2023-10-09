@description('Required. The name of the user assigned identity to modify')
param userAssignedIdentityName string

@description('Required. The name of the federated identity to create')
param name string

param issuerUrl string

param subject string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: userAssignedIdentityName
}

resource federatedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  name: name
  parent: userAssignedIdentity
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: issuerUrl
    subject: subject
  }
}

@description('The resource id of the federated identity')
output id string = federatedIdentity.id
