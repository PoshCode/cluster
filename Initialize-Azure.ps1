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
    # If set, will remove the existing app and service principal, so we can recreate it.
    [switch]$RemoveExisting,

    # The resource group to create. E.g. "rg-poshcode"
    [string]$resourceGroupName = "rg-poshcode",

    # The location to create the resource group in. E.g. "eastus"
    [string]$location = "eastus",

    # The service name to use. E.g. "rg-poshcode-deploy"
    [string]$serviceName = "rg-poshcode-deploy",

    # The repo to set secrets for. E.g. "PoshCode/cluster"
    [string]$repo = "PoshCode/cluster"
)

# Register a bunch of preview features
# "CiliumDataplanePreview" is not working as far as I can tell
foreach ($feature in "AKS-KedaPreview", "AKSNetworkModePreview", "AzureOverlayPreview", "EnableBlobCSIDriver", "EnableNetworkPolicy", "EnableOIDCIssuerPreview", "EnableWorkloadIdentityPreview") {
    # "createNatGateway", "aksOutboundTrafficType", "natGwIdleTimeout"
    # az feature register --name $feature --namespace Microsoft.ContainerService
    Register-AzProviderFeature -FeatureName $feature -ProviderNamespace Microsoft.ContainerService
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
# gh secret set --repo https://github.com/$repo USER_OBJECT_ID -b $spId
