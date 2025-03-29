# PoshCode Kubernetes Cluster

This repo has my gitOps configuration for the PoshCode Kubernetes cluster.

The actual cluster is an AKS cluster deployed with my [Azure Bicep templates](/PoshCode/aks-bicep), which are kept in a separate repository to avoid extra reconciliation.

## Flux GitOps with Kustomize

This is our GitOps repository, and it's all Kustomize yaml, and reconciled by [Flux CD](https://fluxcd.io/).

Three folders are important:

1. The actual cluster applications are in `apps`
2. The `system` folder contains `crds` and `services` (stuff like cert-manager, prometheus, etc)
3. The `clusters` folder has a subfolder for each cluster ...

We follow the [bases and overlays](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays) pattern for Kustomize, so both "apps" and "services" have a `bases` folder with the common configuration, and then a folder for each cluster with the specific configuration. To simplify setup, the `clusters` folder has a subfolder for each cluster, and each of those has flux kustomization to deploy the crds, services, and apps (for that specific cluster) as nested kustomizations.

In other words, each cluster only needs a single Flux Kustomization that points at a subfolder of `clusters`, and the rest of the configuration for the cluster is in this repository.

## GitOps Application Config

In general, each application or service has a helm chart, so the base configuration is a folder in `apps/bases` that just contains the helm `repository` and `release`, and perhaps the http-route or shared secrets.

For each kubernetes cluster, there's then an overlay folder like `apps/production` that specifies the version of the chart and the value overrides to use.

## Troubleshooting & Upgrading

This is purely a demo environment. In almost every case where I've had an upgrade problem (e.g. an issue with loki's chart) I have resolved it by deleting the Flux Kustomization (using the command-line), and allowing flux reconciliation to reinstall it.

One specific instance where that did not work was during the upgrade to release 1.2 of the GRPCRoute CRD (and the corresponding upgrade to 1.17 of Cilium Gateway). Because of the way Kubernetes persists CRDs, once the Cilium Gateway had been upgraded, I had to manually remove the pre-release "v1alpha2" reference from stored versions of the GRPCRoute CRD. See the [notes here](https://gateway-api.sigs.k8s.io/guides/#v12-upgrade-noteshttps://gateway-api.sigs.k8s.io/guides/#v12-upgrade-notes)

## See Also...

A lot of what you'll see here is based on these two Flux examples, which are both simpler and more documented than this repository.

- [Flux Kustomize + Helm](https://github.com/fluxcd/flux2-kustomize-helm-example)
- [Flux Monitoring Example](https://github.com/fluxcd/flux2-monitoring-example)

