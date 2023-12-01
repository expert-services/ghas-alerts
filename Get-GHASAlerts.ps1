<#
    .SYNOPSIS
    This script gathers GitHub Advanced security alerts (code scanning and secret
    scanning), and creates JSON based output for them. Additionally, it gathers
    repository information to enable enriching alert data with repository properties.
 

    .DESCRIPTION
    This script is part of a data transformation process that supports the analysis of
    GitHub Advanced Security alerts. It produces the raw data that can consumed by PowerBI,
    which later could produce structured data. This script requires a GitHub Personal Access
    Token that is able to read security events at the organization level.
 
    .PARAMETER Orgs
    An array of GitHub Organizations to gather alerts from.
 
    .PARAMETER Proxy
    The outbound proxy URL to leverage when interacting with the GitHub API.
   
    .PARAMETER ProxyCred
    The credentials to use to authenticate with the outbound proxy.
    If no credential is specified when calling the script, the script will
    prompt for one to be gathered.
 
    .PARAMETER GitHubToken
    The GitHub token to use to interact with the REST API and gather alerts with.
    If no value is provided, the script will check to see if the environment
    variable GITHUB_TOKEN is present and will use its value. If niether this parameter
    nor a GITHUB_TOKEN environment variable is specified an error will be produced.
 
    .PARAMETER OutputDirectory
    The output directory that code scanning alerts, secret scanning alerts, and
    repsitory information will be written to. If no value is provided, the current
    working directory will be used.
 
    .INPUTS
    None. You can't pipe objects to Get-GHASAlerts.ps1.
 
    .OUTPUTS
    File-based output is created for alerts and repositories. For code scanning
    alerts and repository data, one JSON file per GitHub Organization is created.
    For secret scanning data, many JSON files are created to avoid working
    memory limits.
 
    .EXAMPLE
    $splat = @{
        Orgs = @('expert-services')
        GitHubToken = $env:GITHUB_TOKEN
    }
    .\scripts\Get-GHASAlerts\Get-GHASAlerts.ps1 @splat
 
    .LINK
    See addtional information at: 
 
#>
 
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True)] [array] $Orgs,
    [Parameter(Mandatory = $False)] [string] $Proxy,
    [Parameter(Mandatory = $False)] [pscredential] $ProxyCred,
    [Parameter(Mandatory = $False)] [string] $GitHubToken,
    [Parameter(Mandatory = $False)] [string] $OutputDirectory
)
   
function Get-GitHubOrganizationGHASAlerts {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True)] [ValidateSet('code', 'secret')] [string] $AlertType,
        [Parameter(Mandatory = $True)] [string] $GitHubToken,
        [Parameter(Mandatory = $True)] [string] $Organization,
        [Parameter(Mandatory = $True)] [string] $OutputDirectory,
        [Parameter(Mandatory = $False)] [string] $Proxy,
        [Parameter(Mandatory = $False)] [pscredential] $ProxyCred
    )
    $headers = @{'Authorization' = "token $GitHubToken"}
    $uri = "https://api.github.com/orgs/$Organization/$AlertType-scanning/alerts?page=1&per_page=100"
    $splat = @{
        Method = 'Get'
        ContentType = 'application/json'
        Headers = $headers
    }
    if ($PSBoundParameters.ContainsKey('ProxyCred')) {$splat['ProxyCredential'] = $ProxyCred}
    if ($PSBoundParameters.ContainsKey('Proxy')) {$splat['Proxy'] = $Proxy}
    do {
        $splat['Uri'] = $uri
        try {
            $return = Invoke-WebRequest @splat -ErrorAction Stop
        }
        catch {
            $retryCount = 1
            do {
                Write-Warning "Unable to obtain results for call to $($splat.'Uri'). Attempting retry number $retryCount."
                $return = Invoke-WebRequest @splat
                $retryCount++
            } until (($null -ne $return) -or ($retryCount -eq 4))
        }
        $return.Content | Out-File (Join-Path -Path $OutputDirectory -ChildPath "$Organization-$AlertType-scanning-alerts-$((New-Guid).Guid.Substring(0,8)).json")
        $uri = $return.RelationLink.next
    } until ($null -eq $return.RelationLink.next)
}
   
function Get-GitHubOrganizationRepositories {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True)] [string] $GitHubToken,
        [Parameter(Mandatory = $True)] [string] $Organization,
        [Parameter(Mandatory = $False)] [string] $Proxy,
        [Parameter(Mandatory = $False)] [pscredential] $ProxyCred
    )
    $headers = @{'Authorization' = "token $GitHubToken"}
    $uri = "https://api.github.com/orgs/$Organization/repos?page=1&per_page=100"
    $splat = @{
        Method = 'Get'
        ContentType = 'application/json'
        Headers = $headers
    }
    if ($PSBoundParameters.ContainsKey('ProxyCred')) {$splat['ProxyCredential'] = $ProxyCred}
    if ($PSBoundParameters.ContainsKey('Proxy')) {$splat['Proxy'] = $Proxy}
    do {
        $splat['Uri'] = $uri
        try {
            $return = Invoke-WebRequest @splat -ErrorAction Stop
        }
        catch {
            $retryCount = 1
            do {
                Write-Warning "Unable to obtain results for call to $($splat.'Uri'). Attempting retry number $retryCount."
                $return = Invoke-WebRequest @splat
                $retryCount++
            } until (($null -ne $return) -or ($retryCount -eq 4))
        }
        [array]$repos += $return.Content | ConvertFrom-Json -Depth 100
        $uri = $return.RelationLink.next
    } until ($null -eq $return.RelationLink.next)
    $repos
}
   
function Get-GitHubOrganizationRepositoriesLastCommit {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True)] [string] $GitHubToken,
        [Parameter(Mandatory = $True)] [string] $Organization,
        [Parameter(Mandatory = $False)] [string] $Proxy,
        [Parameter(Mandatory = $False)] [pscredential] $ProxyCred
    )
   
    $url = 'https://api.github.com/graphql'
   
    # GraphQL query with pagination
    $query = @"
query (`$cursor: String) {
  organization(login: "$Organization") {
    repositories(first: 100, after: `$cursor) {
      pageInfo {
        endCursor
        hasNextPage
      }
      nodes {
        name
        refs(
          refPrefix: "refs/heads/"
          first: 1
          orderBy: {field: TAG_COMMIT_DATE, direction: DESC}
        ) {
          nodes {
            name
            target {
              ... on Commit {
                message
                committedDate
              }
            }
          }
        }
      }
    }
  }
}
"@
 
    # Initial request
    $variables = @{cursor = $null}
    $headers = @{
        "Authorization" = "Bearer $GitHubToken"
        "Content-Type" = "application/json"
    }
    $body = @{
        query = $query
        variables = $variables
    } | ConvertTo-Json
    $splat = @{
        Uri = $url
        Method = 'Post'
        Body = $body
        Headers = $headers
    }
    if ($PSBoundParameters.ContainsKey('ProxyCred')) {$splat['ProxyCredential'] = $ProxyCred}
    if ($PSBoundParameters.ContainsKey('Proxy')) {$splat['Proxy'] = $Proxy}
    [array]$return = @()
    $response = Invoke-RestMethod @splat
    $data = $response.data
    $data.organization.repositories.nodes | ForEach-Object {$return += $_}
    while ($data.organization.repositories.pageInfo.hasNextPage) {
        $variables.cursor = $data.organization.repositories.pageInfo.endCursor
        $body = @{
            query = $query
            variables = $variables
        } | ConvertTo-Json
        $splat['Body'] = $body
        try {
            $response = Invoke-RestMethod @splat
            $data = $response.data
        }
        catch {
            $message = $_.ErrorDetails.Message | ConvertFrom-Json | Select-Object -ExpandProperty message
            if ($message -like '*exceeded a secondary rate limit*') {
                [int]$waitTime = $_.Exception.Response.headers | Where-Object {$_.Key -like "Retry-After"} | Select-Object -ExpandProperty Value
                Write-Host "Waiting for secondary rate limits: $($waitTime + 3) seconds"
                Start-Sleep -Seconds ($waitTime + 3)
                $response = Invoke-RestMethod @splat
                $data = $response.data
                continue
            }
            else {
                $retryCount = 1
                $data = $null
                do {
                    Write-Warning "Unable to obtain results for call to $($splat.'Uri'). Attempting retry number $retryCount."
                    $response = Invoke-WebRequest @splat
                    $data = $response.data
                    $retryCount++
                } until (($null -ne $data) -or ($retryCount -eq 4))
                continue
            }
        }
        # Process the data here
        $data.organization.repositories.nodes | ForEach-Object {$return += $_}
    }
    $return
}
   
if (! $PSBoundParameters.ContainsKey('GitHubToken')) {
    if ($null -ne $env:GITHUB_TOKEN) {$GitHubToken = $env:GITHUB_TOKEN} else {
        Write-Error 'No -GitHubToken provided and no GITHUB_TOKEN environment variable found.'
        break
    }
}
   
if (! $PSBoundParameters.ContainsKey('OutputDirectory')) {
    $OutputDirectory = Join-Path -Path (Get-Location).Path -ChildPath 'ghas_alerts'
} else {$OutputDirectory = Join-Path -Path $OutputDirectory -ChildPath 'ghas_alerts'}
 
$OutputDirectory = Join-Path -Path $OutputDirectory -ChildPath (Get-Date -Format FileDateUniversal).ToLower()
if (! (Test-Path -Path $OutputDirectory)) {New-Item -Path $OutputDirectory -ItemType Directory | Out-Null}
foreach ($dir in @('code_scanning_alerts', 'secret_scanning_alerts', 'repos', 'repos_last_commit')) {
    $dir = Join-Path -Path $OutputDirectory -ChildPath $dir
    if (! (Test-Path -Path $dir)) {New-Item -Path $dir -ItemType Directory | Out-Null} else {Remove-Item -Path (Join-Path -Path $dir -ChildPath *) -Recurse -Force}
}
   
$splat = @{GitHubToken = $GitHubToken}
if ($PSBoundParameters.ContainsKey('ProxyCred')) {$splat['ProxyCred'] = $ProxyCred}
if ($PSBoundParameters.ContainsKey('Proxy')) {$splat['Proxy'] = $Proxy}
foreach ($org in $Orgs) {
    $splat['organization'] = $org
    Write-Output "Getting repositories for $org."
    $repos = Get-GitHubOrganizationRepositories @splat
    Write-Output "Creating output for repositories for $org."
    $repos | ConvertTo-Json -Depth 100 | Out-File -Path (Join-Path $OutputDirectory -ChildPath 'repos' -AdditionalChildPath "$org-repos.json").ToLower() -Force
   
    Write-Output "Getting repositories most recent commits for $org."
    $repos = Get-GitHubOrganizationRepositoriesLastCommit @splat
    Write-Output "Creating output for repositories most recent commits for $org."
    $repos | ConvertTo-Json -Depth 100 | Out-File -Path (Join-Path $OutputDirectory -ChildPath 'repos_last_commit' -AdditionalChildPath "$org-repos-last-commit.json").ToLower() -Force
   
    @('code', 'secret') | ForEach-Object {
        $splat['AlertType'] = $_
        $splat['OutputDirectory'] = Join-Path -Path $OutputDirectory -ChildPath ($_ + '_scanning_alerts')
        Write-Output "Getting $_ scanning alerts for $org."
        Get-GitHubOrganizationGHASAlerts @splat
    }
    $splat.Remove('AlertType')
}
 
