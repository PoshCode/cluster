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
    # The identifier URIs to use. E.g. "https://auth.poshcode.com"
    [string[]]$IdentifierUris = "https://auth.poshcode.com",

    # The service name to use. E.g. "poshcode-auth"
    [string]$DisplayName = "poshcode-auth",

    # The repo to set secrets for. E.g. "PoshCode/cluster"
    [string]$repo = "PoshCode/cluster",

    # The name of the secret to create. E.g. "azuread"
    $Name = "azuread",

    # The namespace to create the secret in. E.g. "traefik"
    $Namespace = "traefik",

    # The path to the secret file to create. E.g. "system/config/secret.yaml"
    $Path = "system/config/secret.yaml"
)

Push-Location $PSScriptRoot -StackName Initialize-AuthApplication

filter global:ToBase64 {
    [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($_))
}
filter global:FromBase64 {
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_))
}

$global:app  =  (Get-AzADApplication -DisplayName $DisplayName) ??
                (New-AzADApplication -DisplayName $DisplayName -IdentifierUris $IdentifierUris -ReplyUrls "$IdentifierUris/_oauth")

$Secret = New-AzADAppCredential -ObjectId $App.Id -PasswordCredentials @{}

$Secret = @"
apiVersion: v1
kind: Secret
metadata:
  name: $Name
  namespace: $Namespace
type: Opaque
data:
  client_id: $($app.AppId|ToBase64)
  client_secret: $($secret.SecretText|ToBase64)
  endpoint: $("https://login.microsoftonline.com/$((Get-AzContext).Tenant.Id)/v2.0"|ToBase64)
  random_secret: $([guid]::NewGuid().Guid|ToBase64)
"@

Write-Verbose "$Path`n$Secret"

Set-Content $Path $Secret -Encoding ascii

sops -e -i $Path

Pop-Location -StackName Initialize-AuthApplication

# https://login.microsoftonline.com/$tenant/v2.0/.well-known/openid-configuration
# https://login.microsoftonline.com/$tenant/oauth2/v2.0/authorize