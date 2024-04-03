## Overview
This script gathers GitHub Advanced security alerts (code scanning and secret scanning), and creates JSON based output for them. Additionally, it gathers repository information to enable the enrichment of alert data with repository properties.

This script is part of a data transformation process that supports the analysis of GitHub Advanced Security alerts. It produces the raw data that could be consumed by PowerBI, which could later produce structured data. This script requires a GitHub Personal Access Token that is able to read security events at the organization level.

### Execution
The script can be executed interactively, as follows. 

```
PS> [array]$orgs = @('OctoDemo', 'advanced-security')
PS> $proxy = 'http://my.proxy.com'
PS> [pscredential]$cred = Get-Credential

PowerShell credential request
Enter your credentials.
User: david-wiggs
Password for user david-wiggs: **********

PS> .\scripts\Get-GHASAlerts.ps1 -Orgs $orgs -ProxyCred $cred -Proxy $proxy -GitHubToken $env:GITHUB_TOKEN -OutputDirectory $env:USERPROFILE
```

Alternatively, a credential object can be created so the script can be executed programmatically.

```
PS> [string]$userName = 'david-wiggs'
PS> $proxy = 'http://my.proxy.com'
PS> [securestring]$secStringPassword = ConvertTo-SecureString $env:GITHUB_TOKEN -AsPlainText -Force
PS> [pscredential]$cred = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
PS> [array]$orgs = @('OctoDemo', 'advanced-security')
PS> .\scripts\Get-GHASAlerts.ps1 -Orgs $orgs -ProxyCred $cred -Proxy $proxy -GitHubToken $env:GITHUB_TOKEN -OutputDirectory $env:USERPROFILE

```

## Authentication
A GitHub Personal Access Token must be used when querying APIs. Additionally, credentials can be used to authenticate with an outbound proxy. 

### GitHub Personal Access Token
The Personal Access Token (PAT) that is supplied to the `-gitHubToken` parameter must have the ability to read security events, at minimum, for a GitHub Organization. It is common to use a PAT that has the entire `repo` scope.

![image](/images/pat-scope.jpg "pat-scope")

## Script Output
File-based output is created for alerts and repositories. For repository data, one JSON file per GitHub Organization is created. For alert data, many JSON files are created to avoid working memory limits.

The directory that code scanning alerts, secret scanning alerts, and repository information will be written to is specified by the `-OutputDirectory` parameter. If no value is provided, the current working directory will be used as the output directory.

The directory structure that are created within the output directory is similar to the below, where the date directory is dynamic. If more than one execution of the script occurs on the same day, then content for that day will be **overwritten**.

```
├───ghas_alerts
│   └───20231117Z
|       ├───code_scanning_alerts
|       ├───repos
|       ├───repos_last_commit
|       └───secret_scanning_alerts
```
