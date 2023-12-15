# PoshCode k8s Cluster

This repo has a full bicep deployment for a Kubernetes Cluster, including a github workflow to deploy it, and full yaml to configure all the applications on it.

There are two parts:

1. The **infrastructure** deployment, written in Azure Bicep
2. The **GitOps configuration** (in yaml, in the `clusters`, `system`, and `apps` folders)

## Infrastructure Deployment

I've written my own template for deploying AKS, and it's in the `Infrastructure` folder. It's written in [Azure Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview), and is relatively opinionated. You may want to use the [AKS Constructruction](https://azure.github.io/AKS-Construction/) or [Azure Quickstart Templates](https://learn.microsoft.com/en-us/samples/azure/azure-quickstart-templates/aks/) instead.

### Prerequisites

1. Enable some pre-release features in your Azure tenant
2. Create a resource group in Azure
3. Create a service account in Azure for automation
4. Create secrets in github for authentication as that service account

See [Initialize-Azure](./Initialize-Azure.ps1)` for details. You might call it like this:

```PowerShell
./Initialize-Azure -baseName $name
```

### Deploying

Basically, you're going to run something like this, except we have a [workflow for that](.github/workflows/deploy.yaml):

[![Deploy Kubernetes Cluster](https://github.com/PoshCode/cluster/actions/workflows/deploy.yaml/badge.svg)](https://github.com/PoshCode/cluster/actions/workflows/deploy.yaml)

```PowerShell
$Deployment = @{
    Name = "aks-$(Get-Date -f yyyyMMddThhmmss)"
    ResourceGroupName = "rg-$name"
    TemplateFile = ".\infrastructure\Cluster.bicep"
    TemplateParameterObject = @{
        baseName = "$name"
        adminId = (Get-AzADGroup -Filter "DisplayName eq 'AksAdmins'").Id
    }
}

New-AzResourceGroupDeployment @Deployment
```

## GitOps Configuration

One thing to note is that because this is currently a _public_ repository, there's no need to configure a PAT token or anything for Flux to be able to access it.

The current configuration is using the [Microsoft.Flux](https://learn.microsoft.com/en-us/azure/azure-arc/kubernetes/conceptual-gitops-flux2#flux-cluster-extension) AKS cluster extension to install and configure flux directly from the bicep ARM template.

Of course, if you want to install flux by hand on an existing cluster, it can be as simple as:

```PowerShell
flux bootstrap github --owner PoshCode --repository cluster --path=clusters/poshcode
```

