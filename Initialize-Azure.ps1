<#
    .SYNOPSIS
        Prepares an Azure subscription, resource group, and service account and puts secrets into a GitHub repo.
    .DESCRIPTION
        Creates a new Azure AD application and service principal, and grants it access to a resource group.
        Also creates a new federated identity credential for the service principal, and sets the secrets
        for the repo workflows.
#>
[CmdletBinding()]
param(
    # The base name to use. E.g. the "cluster" name
    [Parameter(Mandatory = $true)]
    [string]$baseName,

    # If set, will remove the existing app and service principal, so we can recreate it.
    [switch]$RemoveExisting,

    # The location to create the resource group in. E.g. "eastus"
    [string]$location = "eastus",

    # The repo to set secrets for. E.g. "PoshCode/cluster"
    [string]$repo = "PoshCode/cluster"
)

# The resource group to create. E.g. "rg-cluster"
$resourceGroupName = "rg-${baseName}"

# The service name to use. E.g. "rg-cluster-deploy"
$serviceName = "rg-${baseName}-deploy"

# Register a bunch of preview features
Get-AzProviderFeature -ProviderNamespace Microsoft.ContainerService -OutVariable enabledFeatures
foreach ($feature in "AKS-KedaPreview", "AKSNetworkModePreview", "AzureOverlayPreview",
    "EnableBlobCSIDriver", "EnableNetworkPolicy", "EnableWorkloadIdentityPreview", "NRGLockdownPreview",
    "NodeOSUpgradeChannelPreview", "IPBasedLoadBalancerPreview") {
    if ($enabledFeatures.Name -notcontains $feature ) {
        Register-AzProviderFeature -FeatureName $feature -ProviderNamespace Microsoft.ContainerService
    }
}

Get-AzProviderFeature -ProviderNamespace Microsoft.KubernetesConfiguration -OutVariable enabledFeatures
foreach ($feature in "FluxConfigurations") {
    if ($enabledFeatures.Name -notcontains $feature ) {
        Register-AzProviderFeature -FeatureName $feature -ProviderNamespace Microsoft.KubernetesConfiguration
    }
}


# Create resource group
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force -Tag @{
    Repo = $repo;
    Purpose = "aks";
    Created = Get-Date -Format "O"
}

$app  = (Get-AzADApplication -DisplayName $serviceName) ??
        (New-AzADApplication -DisplayName $serviceName)
$service  = (Get-AzADServicePrincipal -ApplicationId $app.AppId) ??
            (New-AzADServicePrincipal -ApplicationId $app.AppId)
$role = (Get-AzRoleAssignment -ResourceGroupName $resourceGroupName -RoleDefinitionName Owner -ObjectId $service.Id) ??
        (New-AzRoleAssignment -ResourceGroupName $resourceGroupName -RoleDefinitionName Owner -ObjectId $service.Id)
$fedcred  = (Get-AzADAppFederatedCredential -ApplicationObjectId $app.id) ??
            (New-AzADAppFederatedCredential -ApplicationObjectId $app.Id -Audience "api://AzureADTokenExchange" -Issuer "https://token.actions.githubusercontent.com" -Subject "repo:${repo}:ref:refs/heads/main" -Name "$serviceName-main-gh")

$ctx = Get-AzContext

# Set Secrets for the $repo workflows
gh secret set --repo https://github.com/$repo AZURE_CLIENT_ID -b $app.AppId
gh secret set --repo https://github.com/$repo AZURE_TENANT_ID -b $ctx.Tenant
gh secret set --repo https://github.com/$repo AZURE_SUBSCRIPTION_ID -b $ctx.Subscription.Id
gh secret set --repo https://github.com/$repo AZURE_RG -b $resourceGroupName
# gh secret set --repo https://github.com/$repo USER_OBJECT_ID -b $spId

# Create an AD Group to be administrators of the cluster:
$admins   = (Get-AzADGroup -Filter "DisplayName eq 'AksAdmins'") ??
            (New-AzADGroup -DisplayName AksAdmins -MailNickname AksAdmins -Description "Kubernetes Admins")

gh secret set --repo https://github.com/$repo ADMIN_GROUP_ID -b $admins.Id