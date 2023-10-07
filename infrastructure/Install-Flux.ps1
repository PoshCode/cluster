<#
    .SYNOPSIS
        Installs Flux v2 and bootstraps it to/from a git repository
    .DESCRIPTION
        The `flux bootstrap` command is idempotent, and besides installing (or upgrading) the controllers on the cluster,
        pushes the Flux manifests to the git repository, and configures Flux to update itself from Git.

        Once flux is bootstrapped, any operation on the cluster -- including Flux upgrades, can be done via git push.

        THIS SCRIPT IS OPINIONATED:

        It REQUIRES that you have git, ssh, and flux installed on the machine you are running this script from.

        It REQUIRES that you have a git repository created already to boostrap from (like this one at https://github.com/poshcode/cluster)

        It ALWAYS uses the generic git configuration. The flux binary explicitly supports Github, Azure, GitLab, etc., but I like the simplicity and consistency.

        You must provide an SSH key for authentication. I recommend GitHub's Deploy Keys.
        The key only needs read access to the repository, unless you want to use the image update automation (I do not).
        https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys

        FOR AUTOMATION, WHEN THIS SCRIPT IS RUN FROM A WORKFLOW, IT GENERATES A DEPLOY KEY AND PASSES IT TO FLUX.

        Honestly, I recommend one-off GitHub Deploy Keys:
        - Create a key specifically for this purpose, using a passphrase
        - Upload it in your repo's settings/keys
        - Run the bootstrap
        - Then delete the private key from your machine after bootstrapping
        - Whenever you need to re-run the bootstrap, create a new key

        # TO AVOID THIS, YOU CAN MUST GENERATE THE KEY AHEAD OF TIME AND PASS IT TO THIS SCRIPT:

        $SecureKey = Read-Host "Enter passphrase (empty for no passphrase)" -AsSecureString
        ssh-keygen -t ed25519 -C "Jaykul@HuddledMasses.org" -f secret-id -N="$($SecureKey | ConvertFrom-SecureString -AsPlainText -ErrorAction Ignore)"
        gh repo deploykey add secret-id.pub --repo poshcode/cluster --title "Flux Bootstrap"

        And then pass them to this script: -KeyFile secret-id.key -KeyPass $SecureKey

        See the docs:
            - GitHub: https://fluxcd.io/flux/installation/bootstrap/github/#bootstrap-without-a-github-pat
            - Azure DevOps: https://fluxcd.io/flux/installation/bootstrap/azure-devops/#bootstrap-without-a-devops-pat
#>

[CmdletBinding()]
param(
    # The friendly name for the AKS cluster
    $BaseName = "poshcode",

    # Uri of the git repository to bootstrap flux with.
    # E.g. ssh://git@github.com:PoshCode/cluster.git
    $GitRepositoryUri = "ssh://git@github.com/PoshCode/cluster.git",

    # Even in automation, we want to customize the comment on the key
    $KeyGenComment = "Flux Bootstrapped By https://github.com/Jaykul/",

    # The SSH key file for authenticating to the git repository
    $KeyFile = "$HOME/.ssh/secret-id",

    # The passphrase for the SSH key file
    [SecureString]$KeyPassphrase = $global:KeyPassphrase
)
Push-Location $PSScriptRoot/.. -StackName InstallFlux

# it's literally just a single file binary, but it comes in a zip/tar.gz so we'll just use the install script
$version = if (Get-Command flux) {
    (flux --version) -replace "flux version\s+"
}

if ($version -lt '2.1.1') {
    Write-Warning "Flux version 2.1.1 or higher not found. Please install and try again. Consider either ``choco install flux`` or ``brew install fluxcd/tap/flux``..."
    # In our workflows, we'll just install it ourselves:
    if ($IsLinux -and $PSCmdlet.ShouldContinue("Install Flux?", "Install Flux?")) {
        curl -s https://fluxcd.io/install.sh | sudo bash
    }
}
$ErrorActionPreference = 'Stop'

$repo = $GitRepositoryUri -replace ".*git@[^/]+/|.git$"

"y" |
flux bootstrap git --url=$GitRepositoryUri --branch=main --path="clusters/$BaseName" `
--verbose --components-extra "image-reflector-controller,image-automation-controller" |
    ForEach-Object {
        $_
        if ($_ -match "public key: (.*)") {
            $Matches[1] > flux-key.pub
            gh repo deploy-key add flux-key.pub --repo $repo --title "Flux Bootstrap"
        }
    }

#--private-key-file=$KeyFile `

Pop-Location -StackName InstallFlux


filter base64 {
    [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($_))
}