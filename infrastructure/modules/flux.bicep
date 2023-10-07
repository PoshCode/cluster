@description('Required. The base for resource names (an aks-baseName cluster must exist)')
param baseName string

@description('Required. The url of the gitOps repository.')
param gitOpsRepositoryUrl string

resource cluster 'Microsoft.ContainerService/managedClusters@2023-05-02-preview' existing = {
  name: 'aks-${baseName}'
}

// Supposedly, the extension will be installed automatically when you create the first
// Microsoft.KubernetesConfiguration/fluxConfigurations in a cluster
// But we're installing it by hand to control it more
resource flux 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = {
  name: 'flux'
  scope: cluster
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
    /*  *** If we want to deploy the image reflector and image automation (instead of relying on helm) ***
    configurationSettings: {
      // https://fluxcd.io/flux/components/
      'source-controller.enabled': 'true'
      'kustomize-controller.enabled': 'true'
      'helm-controller.enabled': 'true'
      // https://fluxcd.io/flux/components/notification/ can generate events for source changes
      'notification-controller.enabled': 'true'
      // https://fluxcd.io/flux/components/image/ can update the Git repository when new container images are available
      'image-automation-controller.enabled': 'true'
      'image-reflector-controller.enabled': 'true'
    } // */
  }
  // NOTE: Microsoft.KubernetesConfiguration/extensions MUST BE SEQUENTIAL
  // SEE: https://github.com/Azure/AKS-Construction/issues/385
  // dependsOn: [...]
}

resource fluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
  name: 'flux-system'
  scope: cluster

  properties: {
    sourceKind: 'GitRepository'
    scope: 'cluster'
    namespace: 'flux-system'

    gitRepository: {
      url: gitOpsRepositoryUrl
      syncIntervalInSeconds: 120
      timeoutInSeconds: 180
      // This is important, and is a magic value!
      localAuthRef: 'bootstrap-protected-parameters'
      repositoryRef: {
        branch: 'main'
      }
    }
    kustomizations: {
      cluster: {
        path: 'clusters/${baseName}'
        timeoutInSeconds: 600
        syncIntervalInSeconds: 120
        retryIntervalInSeconds: 660
        prune: true
      }
    }
  }
  // NOTE: Microsoft.KubernetesConfiguration MUST BE SEQUENTIAL
  // SEE: https://github.com/Azure/AKS-Construction/issues/385
  dependsOn: [ flux ]
}

@description('The namespace used by flux for deployments')
output fluxReleaseNamespace string = flux.properties.scope.cluster.releaseNamespace
