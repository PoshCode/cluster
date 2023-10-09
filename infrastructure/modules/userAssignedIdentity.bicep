@description('Required. The base for resource names')
param baseName string

@description('Optional. The location to deploy. Defaults to resourceGroup().location')
param location string = resourceGroup().location

@description('Optional. Tags for this resource. Defaults to resourceGroup().tags')
param tags object = resourceGroup().tags

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'id-${baseName}'
  location: location
  tags: tags
}

@description('The name of the user assigned idenity resource (because it is calculated)')
output name string = userAssignedIdentity.name

@description('Resource ID, for deployment scripts')
output id string = userAssignedIdentity.id

@description('Principal ID, for Azure Role assignement')
output principalId string = userAssignedIdentity.properties.principalId

@description('Client ID, for application config (so we can use this identity from code)')
output clientId string = userAssignedIdentity.properties.clientId
