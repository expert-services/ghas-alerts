<#
    .SYNOPSIS
 

    .DESCRIPTION
    
 
    .PARAMETER Organization


    .PARAMETER Repository

    
    .PARAMETER Proxy
    The outbound proxy URL to leverage when interacting with the GitHub API.
   
    .PARAMETER ProxyCred
    The credentials to use to authenticate with the outbound proxy.
    If no credential is specified when calling the script, the script will
    prompt for one to be gathered.
 
    .PARAMETER GitHubToken
    The GitHub token to use to interact with the REST API and gather workflow artifacts.
    If no value is provided, the script will check to see if the environment
    variable GITHUB_TOKEN is present and will use its value. If niether this parameter
    nor a GITHUB_TOKEN environment variable is specified an error will be produced.
 
    .INPUTS
    None. You can't pipe objects to Get-GHASAlerts.ps1.
 
    .OUTPUTS
     

    .EXAMPLE
    $splat = @{
        Organization = 'expert-services'
        Repository = 'ghas-alerts'
        GitHubToken = $env:GITHUB_TOKEN
    }
    .\scripts\Get-GHASAlerts\Set-GHASAlertData.ps1 @splat
 
    .LINK
    See addtional information at: 
 
#>

function Get-GitHubRepositoryArtifacts {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True)] [string] $GitHubToken,
        [Parameter(Mandatory = $True)] [string] $Organization,
        [Parameter(Mandatory = $True)] [string] $Repository,
        [Parameter(Mandatory = $False)] [string] $Proxy,
        [Parameter(Mandatory = $False)] [pscredential] $ProxyCred
    )
    $headers = @{'Authorization' = "Bearer $GitHubToken"}
    $uri = "https://api.github.com/repos/$Organization/$Repository/actions/artifacts"
    $splat = @{
        Method = 'Get'
        ContentType = 'application/json'
        Headers = $headers
    }
    if ($PSBoundParameters.ContainsKey('ProxyCred')) {$splat['ProxyCredential'] = $ProxyCred}
    if ($PSBoundParameters.ContainsKey('Proxy')) {$splat['Proxy'] = $Proxy}
    $splat['Uri'] = $uri
    Invoke-RestMethod @splat -ErrorAction Stop
}

function Get-GitHubRepositoryLatestArtifact {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True)] [string] $GitHubToken,
        [Parameter(Mandatory = $True)] [string] $Organization,
        [Parameter(Mandatory = $True)] [string] $Repository,
        [Parameter(Mandatory = $False)] [string] $Proxy,
        [Parameter(Mandatory = $False)] [pscredential] $ProxyCred
    )
    $headers = @{
        'Authorization' = "Bearer $GitHubToken"
        'archive_format' = 'zip'
    }
    
    $splat = @{
        Method = 'Get'
        ContentType = 'application/json'
        Headers = $headers
        OutFile = 'ghas-alert-data.zip'
    }
    if ($PSBoundParameters.ContainsKey('ProxyCred')) {$splat['ProxyCredential'] = $ProxyCred}
    if ($PSBoundParameters.ContainsKey('Proxy')) {$splat['Proxy'] = $Proxy}
    $artifacts = Get-GitHubRepositoryArtifacts -GitHubToken $GitHubToken -Organization $Organization -Repository $Repository
    $splat['Uri'] = $artifacts.artifacts | Select-Object -First 1 | Select-Object -ExpandProperty archive_download_url
    Invoke-WebRequest @splat -ErrorAction Stop
}

Get-GitHubRepositoryLatestArtifact -GitHubToken $GitHubToken -Organization $Organization -Repository $Repository
Expand-Archive -Path 'ghas-alert-data.zip' -DestinationPath 'ghas-alert-data' -Force
