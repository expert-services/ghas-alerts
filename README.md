# ghas-alerts

This repository contains a GitHub Action that performs the following tasks:

- Gather secret and code scanning alert data from the REST API
- Gather repository information from the REST API
- Publish the data as an artifact of the workflow run

## Inputs

| Input                       | Description                                                                                                          | Required |
|-----------------------------|----------------------------------------------------------------------------------------------------------------------|----------|
| `github_token`              | The GitHub token to use to interact with the REST API and gather alerts with. This token should have the ability to read security events, at minimum, for a GitHub Organization. It is common to use a token that has the entire `repo` scope. | Yes      |
| `github_orgs`               | The GitHub Organizations to gather data for. This is a comma-separated list of organizations to gather data for.     | Yes      |
| `proxy`                     | The outbound proxy URL to leverage when interacting with the GitHub API.                                             | No       |
| `proxy_credential_password` | The password to use when authenticating with the outbound proxy; `proxy_credential_user` is also required.           | No       |
| `proxy_credential_user`     | The username to use when authenticating with the outbound proxy; `proxy_credential_password` is also required.       | No       |

## Outputs

An Actions workflow artifact `ghas-alert-data` is produced that contains the data gathered from the GitHub REST API.

![artifacts](/images/artifacts.jpg)

A GitHub App could be configured to subscribe to the [`workflow_run`](https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_run) event on this repository, and act as a means to securely fetch this raw data and transfer it into a formal data landing zone.

## Example usage

```yaml
name: ghas-alert-data
on:
  workflow_dispatch:
  schedule:
    - cron: '0 6 * * *'
jobs:
  get-data:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
    steps:
    - name: Get GHAS Alerts
      uses: expert-services/ghas-alerts@main
      with:
        github_token: ${{ secrets.GHAS_ALERT_TOKEN }}
        github_orgs: oodles-noodles
        