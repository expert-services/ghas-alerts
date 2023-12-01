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

## Using GitHub Actions
GitHub actions could be leveraged to provide a compute environment for the script to execute within. A `.github/workflows/ghas-alerts.yml` file similar to the below could be used to execute data collection on a cron-based schedule. 

```
name: ghas-alert-data
on:
  workflow_dispatch:
  schedule:
    - cron: '0 5,6 * * *'
jobs:
  get-data:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
    steps:
    - name: Checkout repository
      uses: actions/checkout@v3
    - name: Execute script
      env:
        GHAS_ALERT_TOKEN: ${{ secrets.GHAS_ALERT_TOKEN }}
        PROXY_USER: ${{ secrets.PROXY_USER }}
        PROXY_PASS: ${{ secrets.PROXY_PASS }}
      run: |
        [securestring]$secStringPassword = ConvertTo-SecureString $env:PROXY_PASS -AsPlainText -Force
        [pscredential]$proxyCred = New-Object System.Management.Automation.PSCredential ($env:PROXY_USER, $secStringPassword)
        $splat = @{
          Orgs = @('OctoDemo', 'advanced-security')
          GitHubToken = $env:GHAS_ALERT_TOKEN
          Proxy = 'http://my.proxy.com'
          ProxyCred = $proxyCred
        }
        ./scripts/Get-GHASAlerts/Get-GHASAlerts.ps1 @splat
      shell: pwsh
    - name: Upload artifact
      uses: actions/upload-artifact@v3
      with:
        name: ghas-alert-data
        path: ghas_alerts/
```

The files that are produced from the script can be uploaded as an artifact. A GitHub App could be configured to subscribe to the [`workflow_run`](https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_run) event on this repository, and act as a means to securely fetch this raw data and transfer it into a formal data landing zone.

![artifacts](/images/artifacts.jpg)
