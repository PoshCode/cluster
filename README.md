# PoshCode k8s Cluster

This repo has my gitOps configuration for the PoshCode Kubernetes cluster.

The actual cluster is an AKS cluster deployed with my [Azure Bicep templates](/PoshCode/aks-bicep), which are kept in a separate repository to avoid extra reconciliation.

## GitOps Configuration

The GitOps configuration is in the `clusters`, `system`, and `apps` folders. It's all in yaml, and it's all managed by [Flux CD](https://fluxcd.io/).

Each cluster gets a base Flux Kustomization that points at a subfolder of `clusters` for it's configuration. That is, each cluster should have it's _own_ folder in the `clusters` folder, and within each there are additional nested Kustomizations to deploy the "system" configuration and any "apps".

## GitOps Application Config

Each application subfolder represents a namespace (sometimes nested in a tenant namespace), and should have an overlay for each cluster that deploys it. Usually the application would have a helm chart, so the base configuration would be the helm repository and release, and the overlays would specify the version and value overrides to use.