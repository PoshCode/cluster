// *** This template deploys the cluster for poshcode.org. See README.md before making changes ***
@description('Optional. This template deploys the cluster for poshcode.org. See README.md before making changes')
var baseName = 'poshcode'

@description('Optional. The url of the gitOps repository. Defaults to https://github.com/PoshCode/cluster obviously')
param gitOpsRepositoryUrl string = 'https://github.com/PoshCode/cluster'

@description('Required. The GUID of the group or user that should have admin rights.')
param adminId string

@description('Optional. The Azure AD tenant GUID. Defaults to the subscription().tenant.Id')
param tenantId string = subscription().tenantId

@description('Optional. The location to deploy. Defaults to resourceGroup().location')
param location string = resourceGroup().location

@description('Optional. Tags for the resource. Defaults to resourceGroup().tags')
param tags object = resourceGroup().tags

@description('Optional. Username of local admin account. Defaults to {baseName}admin')
param vmAdmin string = ''
var vmAdminUser = vmAdmin == '' ? '${baseName}admin' : vmAdmin

// TODO: Get an SSH Key into the shared keyvault
@description('Optional. SSH Key for node admin access.')
param vmAdminSshPublicKey string = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC1sz5ltbHp9evmM9GevZgTbD2Xup2/63pp1lS5gKZU8n1HliS0CDAA23yCFloHi+y14IYz1aTPDRKM3zfz6OWLIaIMPvwN68dvHkCUleFP6mxtSHJGUQ/hIraEGcWp76YlwIvl8zP5iwljlZsraePMwcaKKCivR/ZFwN2bArNObvLk2svPW078AZCQix/c6YJTpUuOioq8W7R+4Zdl6fv4YOYID+vBOpKSZ3g64Qthpy7ZMGlWG+k9TdXfTUY3z837ZglxA6Ztp2ICj6WuNWH6ha88z+otJgdyzXTR+R6JVGS0PkcCCH30eBbnBl6IqH3We2vHJLKoYiELas5o7lPPhAGfS1OCzAcucUCVJEpIZL3fgRGJ6U0qhhHBRISywFPFXglj1XRZIypG8mW+rwQfxXKafWMWgEFZDB2ItHrqbrFHqjCKZPhY/4fDX0bI0GTlJ9XzP62FSp1x12jJ+AQVOdKM43f1w84ECnMeowUrC8TE/JIGGOoaywxOyOP5INk= aks deployment'

@description('Optional. Maximum number of pods to run on a single node. Defaults to 40.')
param maxPodsPerNode int = 40

// @description('Optional. The address prefix (CIDR) for the vnet')
// param vnetAddressPrefix string = '10.100.0.0/16'

// @description('Optional. The address prefix (CIDR) for the vnet')
// param nodeSubnetPrefix string = '10.100.10.0/24'

@description('Optional. Service CIDR for this cluster. Defaults to our shared service CIDR: 10.100.0.0/16')
param serviceCidr string = '10.100.0.0/16'

@description('Optional. IP Address for DNS service (make sure it is inside the serviceCidr). Defaults to 10.100.0.10')
param dnsServiceIP string = '10.100.0.10'

@description('Optional. Pod CIDR for this cluster. Defaults to: 10.192.0.0/16')
param podCidr string = '10.192.0.0/16'

/*
@description('The Log Analytics retention period')
param logRetentionInDays int = 30

@description('The Log Analytics daily data cap (GB) (0=no limit)')
param logDataCap int = 0

@description('Diagnostic categories to log')
param diagnosticCategories array = [
  'cluster-autoscaler'
  'kube-controller-manager'
  'kube-audit-admin'
  'guard'
]
*/

@description('Optional. The AKS AutoscaleProfile has complex defaults I expect to change in production.')
param AutoscaleProfile object = {
  'balance-similar-node-groups': 'true'
  expander: 'random'
  'max-empty-bulk-delete': '3'
  'max-graceful-termination-sec': '600'
  'max-node-provision-time': '15m'
  'max-total-unready-percentage': '45'
  'new-pod-scale-up-delay': '120s'
  'ok-total-unready-count': '3'
  'scale-down-delay-after-add': '10m'
  'scale-down-delay-after-delete': '20s'
  'scale-down-delay-after-failure': '3m'
  'scale-down-unneeded-time': '10m'
  'scale-down-unready-time': '20m'
  'scale-down-utilization-threshold': '0.5'
  'scan-interval': '10s'
  // here be dragons
  'skip-nodes-with-local-storage': 'true'
  'skip-nodes-with-system-pods': 'true'
}

@description('Optional. Select which type of system NodePool to use. Default is "CostOptimized". Other options are "Standard" or "HighSpec"')
@allowed([ 'CostOptimized', 'Standard', 'HighSpec' ])
param systemNodePoolOption string = 'CostOptimized'

@description('''Optional. An array of managedclusters/agentpools for non-system workloads, like:
[
  {
    vmSize: 'Standard_E2bds_v5'
    osDiskSizeGB: 75
    nodeLabels: {
      optimized: 'memory'
      partition: 'apps1'
    }
  }
]

By default, one non-system node pool is created.

For more information on managedclusters/agentpools:
https://learn.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters/agentpools
''')
param additionalNodePoolProfiles array = []

@description('''
Optional. The base version of Kubernetes to use. Node pools are set to auto patch, so they only use the 'major.minor' part.
Defaults to 1.27
''')
param kubernetesVersion string = '1.27'


@description('''Optional. Controls automatic upgrades:
- none. No automatic patching
- node-image: Patch the node OS
- patch. Patch updates applied
- stable. Automatically upgrade to new "stable" releases
- rapid. Always upgrade to new "rapid" releases

For more information on the AKS cluster auto-upgrade channel:
https://learn.microsoft.com/en-us/azure/aks/upgrade-cluster#set-auto-upgrade-channel
''')
@allowed([
  'node-image'
  'none'
  'patch'
  'rapid'
  'stable'
])
param controlPlaneUpgradeChannel string = 'stable'

@description('Optional. Controls how the nodes are patched. Default: NodeImage')
@allowed([
  'NodeImage'
  'None'
  'SecurityPatch'
  'Unmanaged'
])
param clusterNodeOSUpgradeChannel string = 'NodeImage'

// For subdeployments, prefix our name (which is hopefully unique/time-stamped)
var deploymentName = deployment().name

// resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
//   name: 'la-${baseName}'
//   location: location
//   tags: tags
//   properties:  union({
//       retentionInDays: logRetentionInDays
//       sku: {
//         name: 'PerNode'
//       }
//     },
//     logDataCap>0 ? { workspaceCapping: {
//       dailyQuotaGb: logDataCap
//     }} : {}
//   )
// }

// resource containerLogsV2_Basiclogs 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
//   name: 'ContainerLogV2'
//   parent: logAnalytics
//   properties: {
//     plan: 'Basic'
//   }
//   dependsOn: [
//     aks
//   ]
// }

// The actual cluster's identity does not need federation
module kubeletId 'modules/userAssignedIdentity.bicep' = {
  name: '${deploymentName}_uai_kubelet'
  params: {
    baseName: baseName
    location: location
    tags: tags
  }
}


// module vnet 'modules/network.bicep' = {
//   name: '${deploymentName}_vnet'
//   params: {
//     baseName: baseName
//     location: location
//     tags: tags
//     vnetAddressPrefix: vnetAddressPrefix
//     //nodeSubnetPrefix: nodeSubnetPrefix
//   }
// }

module keyVault 'modules/keyVault.bicep' = {
  name: '${deploymentName}_keyvault'
  params: {
    baseName: baseName
    location: location
    tags: tags
  }
}

module aks 'modules/managedCluster.bicep' = {
  name: '${deploymentName}_aks'
  params: {
    baseName: baseName
    location: location
    tags: tags
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${kubeletId.outputs.id}': {}
      }
    }
    controlPlaneUpgradeChannel: controlPlaneUpgradeChannel
    clusterNodeOSUpgradeChannel: clusterNodeOSUpgradeChannel
    // nodeSubnetId: vnet.outputs.nodeSubnetId
    kubernetesVersion: kubernetesVersion
    AutoscaleProfile: AutoscaleProfile
    maxPodsPerNode: maxPodsPerNode
    // logAnalyticsWorkspaceResourceID: logAnalytics.id
    serviceCidr: serviceCidr
    podCidr: podCidr
    systemNodePoolOption: systemNodePoolOption
    vmAdminSshPublicKey: vmAdminSshPublicKey
    vmAdminUser: vmAdminUser
    tenantId: tenantId
    additionalNodePoolProfiles: additionalNodePoolProfiles
    dnsServiceIP: dnsServiceIP
  }
}

module fluxId 'modules/userAssignedIdentity.bicep' = {
  name: '${deploymentName}_uai_fluxId'
  params: {
    baseName: 'flux'
    location: location
    tags: tags
    azureADTokenExchangeFederatedIdentityCredentials: {
      '${aks.outputs.oidcIssuerUrl}': 'system:serviceaccount:flux-system:source-controller'
      '${aks.outputs.oidcIssuerUrl}': 'system:serviceaccount:flux-system:helm-controller'
      '${aks.outputs.oidcIssuerUrl}': 'system:serviceaccount:flux-system:image-reflector-controller'
    }
  }
}

// // Managed Flux
// module flux 'modules/flux.bicep' = {
//   name: '${deploymentName}_flux'
//   params: {
//     baseName: baseName
//     gitOpsRepositoryUrl: gitOpsRepositoryUrl
//   }
//   // technically not, but we're using the deploy to cause some delays...
//   dependsOn: [ aks, fluxId ]
// }

// // Managed monitoring
// module alerts 'modules/metricAlerts.bicep' = {
//   name: '${deploymentName}_alerts'
//   dependsOn: [aks]
//   params: {
//     baseName: baseName
//     location: location
//     logAnalyticsWorkspaceResourceID: logAnalytics.id
//     diagnosticCategories: diagnosticCategories
//   }
// }

module iam_admin_aks 'modules/resourceRoleAssignment.bicep' = {
  name: '${deploymentName}_iam_admin_aks'
  params: {
    principalIds: [ adminId ]
    resourceId: aks.outputs.id
    roleName: 'Azure Kubernetes Service RBAC Cluster Admin'
  }
}

module iam_admin_kv_secrets 'modules/resourceRoleAssignment.bicep' = {
  name: '${deploymentName}_iam_admin_kv_secrets'
  params: {
    principalIds: [ adminId ]
    resourceId: keyVault.outputs.id
    roleName: 'Key Vault Secrets Officer'
  }
}

module iam_admin_kv_crypto 'modules/resourceRoleAssignment.bicep' = {
  name: '${deploymentName}_iam_admin_kv_crypto'
  params: {
    principalIds: [ adminId ]
    resourceId: keyVault.outputs.id
    roleName: 'Key Vault Crypto Officer'
  }
}

module iam_flux_crypto 'modules/resourceRoleAssignment.bicep' = {
  name: '${deploymentName}_iam_flux_crypto'
  params: {
    principalIds: [ fluxId.outputs.principalId ]
    resourceId: keyVault.outputs.id
    roleName: 'Key Vault Crypto User'
  }
}

// @description('Flux release namespace')
// output fluxReleaseNamespace string = flux.outputs.fluxReleaseNamespace

@description('Cluster ID')
output clusterId string = aks.outputs.id

@description('User Assigned Identity Resource ID, required by deployment scripts')
output kubeletIdentityResourceID string = kubeletId.outputs.id

@description('User Assigned Identity Object ID, used for Azure Role assignement')
output kubeletIdentityPrincipalId string = kubeletId.outputs.principalId

@description('User Assigned Identity Client ID, used for application config (so we can use this identity from code)')
output kubeletIdentityClientId string = kubeletId.outputs.clientId

@description('User Assigned Identity Resource ID, required by deployment scripts')
output fluxIdResourceID string = fluxId.outputs.id

@description('User Assigned Identity Object ID, used for Azure Role assignement')
output fluxIdPrincipalId string = fluxId.outputs.principalId

@description('User Assigned Identity Client ID, used for application config (so we can use this identity from code)')
output fluxIdClientId string = fluxId.outputs.clientId

@description('Uri for the sops-key to be used for secret encryption')
output sopsKeyId string = keyVault.outputs.sopsKeyId

// output LogAnalyticsName string = logAnalytics.name
// output LogAnalyticsGuid string = logAnalytics.properties.customerId
// output LogAnalyticsId string = logAnalytics.id
