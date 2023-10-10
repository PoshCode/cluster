<#
    .SYNOPSIS
        Bootstraps Flux v2 to/from a git repository
    .DESCRIPTION
        The `flux bootstrap` command is idempotent, and besides installing (or upgrading) the controllers on the cluster,
        pushes the Flux manifests to the git repository, and configures Flux to update itself from Git.

        Once flux is bootstrapped, any operation on the cluster -- including Flux upgrades, can be done via git push.
    .EXAMPLE
        Initialize-Flux -GitRepositoryUri ssh://git@github.com/PoshCode/cluster.git

        Initialize flux on the current kubectl context to the specified git repository (using SSH keys).
    .EXAMPLE
        $Token = .\scripts\New-AdoPat -ServiceAccount adogitk8s_svc@loandepot.com -Scope vso.code_write -DisplayName aks-loandepotdev-azusw2-dvo-sl1
        Connect-AzContext SL1
        $Token | .\scripts\Initialize-Flux -GitRepositoryUri https://dev.azure.com/LDEnterprise/Enterprise/_git/LD.Kubernetes.Infrastructure -AuthorEmail DevOps@loandepot.com

        Generate a new PAT token for a service account, connect to that context, and bootstrap flux to the specified git repository.
        NOTE: The PAT token has to be able to PUSH to the "main" branch of the repository
#>

[CmdletBinding(DefaultParameterSetName = 'Bootstrap')]
param(
    # The name of the AKS cluster
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [Alias('DisplayName')]
    [string]$ClusterName = "poshcode",

    # Uri of the git repository to bootstrap flux with.
    # Must use URI syntax, starting with https:// or ssh:// (and using a / after the domain name)
    # E.g. ssh://git@github.com/PoshCode/cluster.git
    $GitRepositoryUri = "https://LDEnterprise@dev.azure.com/LDEnterprise/Enterprise/_git/LD.Kubernetes.Infrastructure",

    # If you can't push to the main branch, you need to use this option
    [Parameter(ParameterSetName = 'Install')]
    [switch]$UsePullRequest,

    # A local file path where target git repository has already been cloned
    # If you are using a different repo for bicep and gitops, you'd checkout both repos in the workflow
    # And pass the path to the gitops repo here
    [Parameter(ParameterSetName = 'Install')]
    [string]$WorkspaceFolder,

    # A Personal Access Token (PAT) for the git repository
    [Parameter(Mandatory, ParameterSetName = 'Bootstrap', ValueFromPipelineByPropertyName)]
    [securestring]$Token,

    # Author Email for git commits
    [string]$AuthorEmail = 'jaykul@users.noreply.github.com',

    # Author Name for git commits (default is "Flux")
    [string]$AuthorName = "Flux",

    # The containers (and service accounts) to use workload identity for.
    [ValidateSet("helm-controller", "image-automation-controller", "image-reflector-controller", "kustomize-controller", "source-controller")]
    [string[]]$WorkloadIdentityContainers,

    # To use workload identity for the flux service accounts, specify the client ID and tenant ID
    [string]$TenantId,

    # To use workload identity for the flux service accounts, specify the client ID and tenant ID
    [string]$ClientId,

    # To patch the Helm controller to enable OOM watch, specify this switch
    [switch]$OomWatch
)
begin {
    $version = if (Get-Command flux) {
        (flux --version) -replace "flux version\s+"
    }

    if ($version -lt '2.1.1') {
        Write-Warning "Flux version 2.1.1 or higher not found. Please install and try again. Consider either ``choco install flux`` or ``brew install fluxcd/tap/flux``..."
        # In our workflows, we can just install it ourselves:
        if ($IsLinux) {
            # it's just a single file binary in a tar.gz, but use their install script:
            curl -s https://fluxcd.io/install.sh | sudo bash
        }
    }
    $ErrorActionPreference = 'Stop'
}
process {
    # If the cluster name has a space in it (for instance, because we include the date in PAT displayName), only use the first part
    $ClusterName = ($ClusterName.ToLowerInvariant() -split ' ')[0]

    # We can't commit directly to main, what are we to do?
    if ($UsePullRequest) {
        if (!$WorkspaceFolder) {
            $path = Join-Path ([Io.Path]::GetTempPath()) ([Guid]::NewGuid().Guid) $ClusterName
            $WorkspaceFolder = New-Item -ItemType Directory -Force -Path $path | Convert-Path
            git clone $GitRepositoryUri $WorkspaceFolder --depth 1
        }
        Push-Location $WorkspaceFolder -StackName 'Initialize-Flux'

        $FluxSystemPath = Join-Path clusters $ClusterName flux-system
        $null = New-Item -ItemType Directory -Force -Path $FluxSystemPath

        # Always re-create the gotk-components.yaml file
        flux install --components-extra "image-reflector-controller,image-automation-controller" --export
        | Set-Content (Join-Path $FluxSystemPath gotk-components.yaml)
        git add (Join-Path $FluxSystemPath gotk-components.yaml)

        # Apply the gotk-components file first (because it has CRDs)
        kubectl apply -f (Join-Path $FluxSystemPath gotk-components.yaml)

        $BootStrapping = $false
        # Only create the bootstrap.yaml file if it doesn't exist
        if (!(Test-Path ($bootstrap = Join-Path $FluxSystemPath bootstrap.yaml))) {
            $BootStrapping = $true
            # Create the bootstrap.yaml file
            $Content = Get-Content (Join-Path clusters bootstrap.yaml)
            $Content = $Content -replace "url:.*", "url: $GitRepositoryUri"
            $Content = $Content -replace "path:.*", "path: clusters/$ClusterName"
            $Content | Set-Content $Bootstrap
            git add $Bootstrap
        }

        if ($BootStrapping) {
            if ($Token) {
                flux create secret git bootstrap-protected-parameters --url=$GitRepositoryUri --token=$(ConvertFrom-SecureString $Token -AsPlainText)
            } else {
                $publicKey = flux create secret git bootstrap-protected-parameters --url=$GitRepositoryUri
                $publicKey = $publicKey -split "\n" -match "deploy key:" -replace ".*deploy key: "
                if (Get-Command gh -ErrorAction SilentlyContinue) {
                    $publicKey > deploy.pub
                    gh repo deploy-key add deploy.pub -t "Flux v$version"
                    Remove-Item deploy.pub
                }
                Write-Warning "You need to add this public key to your git repository as a deploy key: `n$publicKey"
            }
        }

        # Only create the kustomization.yaml file if it doesn't exist
        if (!(Test-Path ($kustomization = Join-Path $FluxSystemPath kustomization.yaml))) {
            $BootStrapping = $true
            # Create the kustomization.yaml file
            Set-Content $kustomization (@(
                "apiVersion: kustomize.config.k8s.io/v1beta1"
                "kind: Kustomization"
                "resources:"
                "- gotk-components.yaml"
                "- bootstrap.yaml"
                ""
            ) -join "`n")

            if ($WorkloadIdentityContainers -or $OomWatch) {
                Add-Content $kustomization "patches:"
                if ($WorkloadIdentityContainers) {
                    $Patch = Get-Content (Join-Path clusters workload-identity-patch.yaml) -Raw
                    $Patch = $Patch -replace "name: `"\(.*\)`"", "name: `"($WorkloadIdentityContainers -join '|')`""
                    if ($TenantId -and $ClientId) {
                        $Patch = $Patch -replace "azure.workload.identity/client-id:.*", "azure.workload.identity/client-id: $ClientId"
                        $Patch = $Patch -replace "azure.workload.identity/tenant-id:.*", "azure.workload.identity/tenant-id: $TenantId"
                    }
                    Add-Content $kustomization $Patch
                }
                if ($WorkloadIdentityContainers -contains "kustomize-controller") {
                    $Patch = Get-Content (Join-Path clusters azure-auth-patch.yaml)
                    Add-Content $kustomization $Patch
                }
                if ($OomWatch) {
                    $Patch = Get-Content (Join-Path clusters oom-watch-patch.yaml)
                    Add-Content $kustomization $Patch
                }
            }
            git add $kustomization
        }

        # Commit the changes
        if ($BootStrapping) {
            git config --global user.name $AuthorName
            git config --global user.email $AuthorEmail
            git switch -C "bootstrap-flux-v$version"
            git commit -m "Bootstrap Flux v$version"
            git push

            Write-Warning "You need to create a pull request to merge the 'bootstrap-flux-v$version' branch into main."
        }

        # (Re)apply the flux-system kustomization
        kubectl apply -k $FluxSystemPath
    } else {
        # In a workflow, we won't have an SSH key ...
        if (!$Token -and ($GitRepositoryUri | Split-Path -Qualifier) -eq "ssh:") {

            # Flux would generate a new SSH key, and register it for you...
            "y" |
                flux bootstrap git --url=$GitRepositoryUri --path="clusters/$ClusterName" `
                    --author-name=$AuthorName --author-email=$AuthorEmail `
                    --verbose --components-extra "image-reflector-controller,image-automation-controller"
        } else {
            $Env:GIT_PASSWORD = $token | ConvertFrom-SecureString -AsPlainText
            flux bootstrap git --token-auth --url=$GitRepositoryUri --path="clusters/$ClusterName" `
                --author-name=$AuthorName --author-email=$AuthorEmail `
                --verbose --components-extra "image-reflector-controller,image-automation-controller"
        }
    }
}





<#
    .NOTES
        For original, see https://github.com/PoshCode/cluster

        THIS SCRIPT IS OPINIONATED:

        It ALWAYS uses the generic git configuration. The flux binary explicitly supports Github, Azure, GitLab, etc., but I like the simplicity and consistency.

        It therefore REQUIRES that you have a git repository created already to boostrap from (like this one at https://github.com/poshcode/cluster)

        You have two options:

        ## Provide an SSH key for authentication. I recommend GitHub's Deploy Keys.

        In this mode, you'll need to be able to `git clone` using the SSH.
        Flux may generate a new key and even register it for you, depending on your git provider, or may prompt.
        The key only needs read access to the repository, unless you want to use the image update automation (I do not).
        https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys

        I strongly recommend one-off GitHub Deploy Keys:
        - Create a key specifically for this purpose, using a passphrase
        - Upload it in your repo's settings/keys
        - Run the bootstrap
        - Then delete the private key from your machine after bootstrapping
        - Whenever you need to re-run the bootstrap, create a new key

        ## Provide a Personal Access Token (PAT) for authentication.

        In this mode, you'll need to be able to `git clone` using the HTTPS protocol using the PAT token, and the token must have write access to the repository and be able to commit directly to the "main" branch.

#>



