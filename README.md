# PoshCode k8s Cluster

This repo has a full bicep deployment for a Kubernetes Cluster, including a github workflow to deploy it, and full yaml to configure all the applications on it.

There are two parts:

1. The **infrastructure** deployment, written in Azure Bicep
2. The **GitOps configuration** (in yaml, in the `clusters`, `system`, and `apps` folders)

## Infrastructure Deployment

I've written my own templates for deploying AKS, and they are in the `infrastructure` folder. I wrote them in [Azure Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview), and I've been maintaining them for a number of years at this point. They are relatively opinionated as to what features I use, and I last overhauled them completely in late 2023. I'm still maintaining them, and doing clean deploys as of March 2024. If you're not interested in my IAC, you can use the rest of this on any Kubernetes cluster. If you're targeting AKS, you should consider the [AKS Construction](https://azure.github.io/AKS-Construction/) as an alternative. There are also AKS templates in the [Azure Quickstart Templates](https://learn.microsoft.com/en-us/samples/azure/azure-quickstart-templates/aks/), although those are relatively simplistic -- fine for a test case or demo, but perhaps not for your production cluster.

### Azure Prerequisites

These pre-requisites are not part of the CI/CD build, because they only have to be done once, but the [Initialize-Azure](./Initialize-Azure.ps1) script is essentially idempotent and re-runnable.

1. Enable some features in your Azure tenant (some of which are pre-release features as of this writing)
2. Create a resource group in Azure to deploy to
3. Create a service account in Azure for automation
4. Assign the "owner" role on the resource group to the service account
5. Create secrets in github for authentication as that service account

The first step, enabling features, only has to be done once per subscription. For best practices, the remaining steps should be done once for each cluster, for security purposes. The idea is that the subscription owner runs this script by hand, and then the automated service account is restricted to deploying to this single resource group.

See [Initialize-Azure](./Initialize-Azure.ps1)` for details. You might call it like this:

```PowerShell
./Initialize-Azure -baseName $name
```

### Deploying Infrastructure

Each time the IAC templates change, we're going to run New-AzResourceGroupDeployment, but we have a [workflow for that](.github/workflows/deploy.yaml), of course.

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
